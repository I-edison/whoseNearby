import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';
import 'auth_storage.dart';

/// In-app notification polling + local notifications (FCM-ready shell).
class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  final Set<String> _seen = {};
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
    _poll();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final token = await AuthStorage.instance.getToken();
      if (token == null || token.isEmpty) return; // not logged in yet
      final data = await ApiClient.instance.get('/notifications', auth: true)
          as Map<String, dynamic>;
      final list = (data['notifications'] as List?) ?? [];
      for (final n in list) {
        final m = Map<String, dynamic>.from(n as Map);
        final id = m['id']?.toString() ?? '';
        final read = m['read'] == true;
        if (id.isEmpty || read || _seen.contains(id)) continue;
        _seen.add(id);
        await showLocal(
          title: m['title']?.toString() ?? 'WhoseNearby',
          body: m['body']?.toString() ?? '',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('notif poll: $e');
    }
  }

  Future<void> showLocal({required String title, required String body}) async {
    if (!_ready) await init();
    const android = AndroidNotificationDetails(
      'whosenearby_main',
      'WhoseNearby',
      channelDescription: 'Jobs, chat, and payments',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android, iOS: DarwinNotificationDetails()),
    );
  }
}
