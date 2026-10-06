import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'auth_storage.dart';

/// Real-time chat over WebSocket (ws://host/ws?token=JWT).
class ChatSocket {
  ChatSocket._();
  static final ChatSocket instance = ChatSocket._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  String? _jobId;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;
  bool get isConnected => _channel != null;

  String _wsUrl(String token) {
    final base = ApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$root/ws?token=${Uri.encodeComponent(token)}';
  }

  Future<void> connect() async {
    final token = await AuthStorage.instance.getToken();
    if (token == null || token.isEmpty) return;

    await disconnect();

    try {
      final url = _wsUrl(token);
      if (kDebugMode) debugPrint('WS connect $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final map = jsonDecode(data.toString()) as Map<String, dynamic>;
            _controller.add(map);
          } catch (_) {}
        },
        onError: (e) {
          if (kDebugMode) debugPrint('WS error $e');
        },
        onDone: () {
          if (kDebugMode) debugPrint('WS closed');
          _channel = null;
        },
      );

      // Keepalive
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        send({'type': 'ping'});
      });

      // Re-join room if we had one
      if (_jobId != null) {
        join(_jobId!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WS connect failed $e');
      _channel = null;
    }
  }

  void join(String jobId) {
    _jobId = jobId;
    send({'type': 'join', 'jobId': jobId});
  }

  void leave() {
    send({'type': 'leave'});
    _jobId = null;
  }

  void send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _ping?.cancel();
    _ping = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
