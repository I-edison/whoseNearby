import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/chat_service.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/chat_socket.dart';
import '../../services/media_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _jobId;
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _messages = [];
  String? _myId;
  bool _loading = true;
  bool _sending = false;
  bool _releasing = false;
  bool _showJump = false;
  final bool _peerTyping = false;
  Timer? _typingHide;
  final _textCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _poll;
  StreamSubscription? _wsSub;
  final _timeFmt = DateFormat('h:mm a');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_jobId == null) {
      _jobId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_jobId != null) _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _wsSub?.cancel();
    _typingHide?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    ChatSocket.instance.leave();
    _textCtrl.dispose();
    _codeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final show = max - _scrollCtrl.position.pixels > 120;
    if (show != _showJump && mounted) setState(() => _showJump = show);
  }

  void _startRealtime() {
    _poll?.cancel();
    _wsSub?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.addListener(_onScroll);

    // WebSocket: instant messages + read receipts
    ChatSocket.instance.connect().then((_) {
      if (_jobId != null) ChatSocket.instance.join(_jobId!);
    });

    _wsSub = ChatSocket.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'message') {
        final msg = event['message'];
        if (msg is Map) {
          final map = Map<String, dynamic>.from(msg);
          final id = map['id']?.toString();
          // Skip if we already have it (optimistic or poll)
          if (id != null && _messages.any((m) => m['id']?.toString() == id)) {
            return;
          }
          setState(() {
            _messages = [..._messages, map];
          });
          _scrollToEnd();
        }
      } else if (type == 'read') {
        // Peer read our messages — refresh read ticks
        _refreshQuiet();
      } else if (type == 'joined') {
        // room ready
      }
    });

    // Fallback poll every 8s if WS drops packets
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _jobId == null || _sending || _releasing) return;
      _refreshQuiet();
    });
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(max, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var user = await AuthService.instance.currentUser();
      user ??= await AuthService.instance.me();
      final job = await JobService.instance.getById(_jobId!);
      final messages = await ChatService.instance.messages(_jobId!);
      if (!mounted) return;
      setState(() {
        _myId = user?['id']?.toString();
        _job = job;
        _messages = messages;
        _loading = false;
      });
      _startRealtime();
      _scrollToEnd(animated: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _readFingerprint(List<Map<String, dynamic>> list) {
    return list.map((m) => '${m['id']}:${m['readAt']}').join('|');
  }

  Future<void> _refreshQuiet() async {
    if (_jobId == null) return;
    try {
      final job = await JobService.instance.getById(_jobId!);
      final messages = await ChatService.instance.messages(_jobId!);
      if (!mounted) return;
      final lastOld = _messages.isNotEmpty ? _messages.last['id'] : null;
      final lastNew = messages.isNotEmpty ? messages.last['id'] : null;
      final lenChanged = messages.length != _messages.length;
      final statusChanged = job['status']?.toString() != _job?['status']?.toString();
      final readChanged = _readFingerprint(messages) != _readFingerprint(_messages);
      if (!lenChanged && !statusChanged && lastOld == lastNew && !readChanged) return;
      final wasNearBottom = _scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 80;
      setState(() {
        _job = job;
        _messages = messages;
      });
      if (lenChanged && wasNearBottom) _scrollToEnd();
    } catch (_) {}
  }

  Future<void> _send({String? text, double? offerAmount}) async {
    final body = text ?? _textCtrl.text.trim();
    if ((body.isEmpty && offerAmount == null) || _jobId == null) return;
    final displayBody = body.isEmpty ? 'Offer: ${offerAmount!.toStringAsFixed(0)}' : body;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = <String, dynamic>{
      'id': tempId,
      'senderId': _myId,
      'body': displayBody,
      'offerAmount': offerAmount,
      'createdAt': DateTime.now().toIso8601String(),
      'readAt': null,
      'pending': true,
    };
    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
    });
    if (text == null) _textCtrl.clear();
    _scrollToEnd();
    try {
      final sent = await ChatService.instance.send(_jobId!, body: displayBody, offerAmount: offerAmount);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((m) => m['id'] == tempId ? Map<String, dynamic>.from(sent as Map) : m)
            .toList();
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m['id'] != tempId).toList();
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m['id'] != tempId).toList();
        _sending = false;
      });
    }
  }

  double? get _latestOffer {
    for (final m in _messages.reversed) {
      final o = m['offerAmount'];
      if (o is num) return o.toDouble();
    }
    final agreed = _job?['agreedAmount'];
    if (agreed is num) return agreed.toDouble();
    final artisan = _job?['artisan'] as Map<String, dynamic>?;
    final rate = artisan?['hourlyRate'];
    if (rate is num) return rate.toDouble();
    return null;
  }

  bool get _isClient => _job?['clientId']?.toString() == _myId;
  bool get _isArtisan {
    final art = _job?['artisan'];
    if (art is Map) {
      final uid = art['userId']?.toString() ??
          (art['user'] is Map ? (art['user'] as Map)['id']?.toString() : null);
      return uid != null && uid == _myId;
    }
    return false;
  }
  bool get _jobOpen {
    final s = _job?['status']?.toString() ?? '';
    return s == 'OPEN' || s == 'NEGOTIATING' || s.isEmpty;
  }

  Future<void> _acceptOffer(double amount) async {
    if (_jobId == null) return;
    if (_isClient) {
      await Navigator.pushNamed(context, '/confirm-pay', arguments: {
        'jobId': _jobId,
        'amount': amount,
        'title': _job?['title'],
        'peer': (_job?['artisan'] as Map?)?['businessName'] ?? 'Artisan',
      });
      await _load();
      return;
    }
    await _send(
      text: 'Accepted offer of ${amount.toStringAsFixed(0)}. Ready when you are.',
      offerAmount: amount,
    );
  }

  Future<void> _releasePayment() async {
    final code = _codeCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit code from the artisan'),
        ),
      );
      return;
    }
    setState(() => _releasing = true);
    try {
      await JobService.instance.complete(jobId: _jobId!, code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment released — rate your experience'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacementNamed(context, '/rate', arguments: _jobId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not release payment. Check the code and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _openNegotiateSheet() async {
    final ctrl = TextEditingController(text: _latestOffer?.toStringAsFixed(0) ?? '');
    final noteCtrl = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Propose a price',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Amount'),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: 'NGN '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Send offer',
                onPressed: () {
                  final amount = double.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx, {'amount': amount, 'note': noteCtrl.text.trim()});
                },
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    final amount = result['amount'] as double;
    final note = result['note'] as String? ?? '';
    await _send(text: note.isEmpty ? 'Price offer' : note, offerAmount: amount);
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      return _timeFmt.format(DateTime.parse(raw.toString()).toLocal());
    } catch (_) {
      return '';
    }
  }

  String _dayLabel(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('EEE, d MMM').format(d);
    } catch (_) {
      return '';
    }
  }

  bool _isNewDay(int i) {
    if (i == 0) return true;
    final a = _messages[i]['createdAt'];
    final b = _messages[i - 1]['createdAt'];
    try {
      final da = DateTime.parse(a.toString()).toLocal();
      final db = DateTime.parse(b.toString()).toLocal();
      return da.year != db.year || da.month != db.month || da.day != db.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _quickSend(String text) {
    _textCtrl.text = text;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? artisan;
    if (_job?['artisan'] is Map) {
      artisan = Map<String, dynamic>.from(_job!['artisan'] as Map);
    }
    Map<String, dynamic>? client;
    if (_job?['client'] is Map) {
      client = Map<String, dynamic>.from(_job!['client'] as Map);
    }
    Map<String, dynamic>? artisanUser;
    if (artisan != null && artisan['user'] is Map) {
      artisanUser = Map<String, dynamic>.from(artisan['user'] as Map);
    }

    final bool isClientView =
        _myId != null && client != null && client['id']?.toString() == _myId;

    String peerName;
    String peerLetter;
    String? peerAvatarPath;

    if (isClientView) {
      peerName = artisan?['businessName']?.toString() ?? 'Artisan';
      peerLetter = artisanUser?['avatarLetter']?.toString() ??
          (peerName.isNotEmpty ? peerName[0] : 'A');
      peerAvatarPath = artisanUser?['avatarUrl']?.toString();
    } else {
      peerName = client?['fullName']?.toString() ?? 'Client';
      peerLetter = client?['avatarLetter']?.toString() ??
          (peerName.isNotEmpty ? peerName[0] : 'C');
      peerAvatarPath = client?['avatarUrl']?.toString();
    }

    if (peerAvatarPath == 'null') {
      peerAvatarPath = null;
    }
    final peerAvatarUrl = MediaService.resolveUrl(peerAvatarPath);
    final status = _job?['status']?.toString() ?? '';
    final amount = _latestOffer;
    final canPay = status == 'NEGOTIATING' || status == 'OPEN';
    final canNegotiate = status == 'NEGOTIATING' || status == 'OPEN' || status.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F1),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(
              letter: peerLetter,
              size: 36,
              imageUrl: peerAvatarUrl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: status == 'IN_PROGRESS'
                              ? const Color(0xFF22C55E)
                              : AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          status.isEmpty
                              ? 'Active now'
                              : status.replaceAll('_', ' ').toLowerCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.primary600,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canNegotiate)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _sending ? null : _openNegotiateSheet,
                icon: const Icon(Icons.handshake_outlined, size: 18),
                label: Text(
                  'Offer',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary700),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      if (_messages.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary050,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 36,
                                    color: AppColors.primary600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Say hello',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Agree on scope and price here. Offers and payments stay in this thread.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.inkSoft,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];
                            final senderId = m['senderId']?.toString() ??
                                (m['sender'] as Map?)?['id']?.toString();
                            final isMe = senderId != null &&
                                _myId != null &&
                                senderId == _myId;
                            final body = m['body']?.toString() ?? '';
                            final offer = m['offerAmount'];
                            final time = _formatTime(m['createdAt']);
                            final pending = m['pending'] == true;
                            final read = m['readAt'] != null;

                            Widget bubble;
                            if (offer != null) {
                              final offerAmount = (offer as num).toDouble();
                              final showAccept = !isMe && _jobOpen;
                              bubble = Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.78,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isMe
                                          ? [
                                              AppColors.primary700,
                                              AppColors.primary600,
                                            ]
                                          : [
                                              AppColors.primary050,
                                              const Color(0xFFE8F5EE),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary700
                                            .withValues(alpha: 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMe ? 'YOUR OFFER' : 'OFFER RECEIVED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isMe
                                              ? Colors.white70
                                              : AppColors.inkFaint,
                                        ),
                                      ),
                                      Text(
                                        'NGN ${offerAmount.toStringAsFixed(0)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                          color: isMe
                                              ? Colors.white
                                              : AppColors.primary700,
                                        ),
                                      ),
                                      _MetaRow(
                                        time: time,
                                        isMe: isMe,
                                        pending: pending,
                                        read: read,
                                        onDark: isMe,
                                      ),
                                      if (showAccept) ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: _sending
                                                ? null
                                                : () =>
                                                    _acceptOffer(offerAmount),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isMe
                                                  ? Colors.white
                                                  : AppColors.primary700,
                                              foregroundColor: isMe
                                                  ? AppColors.primary700
                                                  : AppColors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              _isClient
                                                  ? 'Accept & pay'
                                                  : 'Accept offer',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              bubble = Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: body.isEmpty
                                      ? null
                                      : () => _copyText(body),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.78,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 10, 14, 6),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.primary700
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft:
                                            Radius.circular(isMe ? 18 : 4),
                                        bottomRight:
                                            Radius.circular(isMe ? 4 : 18),
                                      ),
                                      border: isMe
                                          ? null
                                          : Border.all(color: AppColors.line),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          body,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            height: 1.4,
                                            color: isMe
                                                ? AppColors.white
                                                : AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        _MetaRow(
                                          time: time,
                                          isMe: isMe,
                                          pending: pending,
                                          read: read,
                                          onDark: isMe,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: [
                                if (_isNewDay(i))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: AppColors.line),
                                        ),
                                        child: Text(
                                          _dayLabel(m['createdAt']),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                bubble,
                              ],
                            );
                          },
                        ),
                      if (_showJump)
                        Positioned(
                          right: 12,
                          bottom: 8,
                          child: Material(
                            color: AppColors.surface,
                            elevation: 3,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Jump to latest',
                              onPressed: () => _scrollToEnd(),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        if (canPay && amount != null && _isClient)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PrimaryButton(
                              label:
                                  'Accept & start — NGN ${amount.toStringAsFixed(0)}',
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/confirm-pay',
                                arguments: {
                                  'jobId': _jobId,
                                  'amount': amount,
                                  'title': _job?['title'],
                                  'peer': peerName,
                                },
                              ).then((_) => _load()),
                            ),
                          ),

                        if (status == 'IN_PROGRESS' && _isArtisan) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary050,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'COMPLETION CODE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkFaint,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (_job?['completionCode']?.toString() ?? '······'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 6,
                                      color: AppColors.primary700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Share this with the client only when the job is finished. They use it to release your payment.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (status == 'IN_PROGRESS' && _isClient)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _codeCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    hintText: 'Completion code',
                                  ),
                                ),
                                PrimaryButton(
                                  label: 'Release payment',
                                  loading: _releasing,
                                  onPressed: _releasing ? null : _releasePayment,
                                ),
                              ],
                            ),
                          ),

                        if (_messages.isEmpty || _messages.length < 4)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final q in const [
                                    'Hi, are you available?',
                                    'What is your rate?',
                                    'I can start today',
                                    'Thanks!',
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: Text(
                                          q,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed:
                                            _sending ? null : () => _quickSend(q),
                                        backgroundColor: AppColors.primary050,
                                        side: const BorderSide(
                                            color: AppColors.primary100),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.line),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed:
                                    _sending ? null : _openNegotiateSheet,
                                tooltip: 'Make an offer',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary050,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.payments_rounded,
                                    size: 20,
                                    color: AppColors.primary700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _textCtrl,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  minLines: 1,
                                  maxLines: 4,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Message…',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      color: AppColors.inkFaint,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              Material(
                                color: AppColors.primary700,
                                borderRadius: BorderRadius.circular(22),
                                child: InkWell(
                                  onTap: _sending ? null : () => _send(),
                                  borderRadius: BorderRadius.circular(22),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String time;
  final bool isMe;
  final bool pending;
  final bool read;
  final bool onDark;

  const _MetaRow({
    required this.time,
    required this.isMe,
    required this.pending,
    required this.read,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        onDark ? Colors.white.withValues(alpha: 0.75) : AppColors.inkFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time.isNotEmpty)
          Text(
            time,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: color),
          ),
        if (isMe) ...[
          const SizedBox(width: 4),
          if (pending)
            Icon(Icons.access_time, size: 12, color: color)
          else
            Icon(
              read ? Icons.done_all : Icons.done,
              size: 14,
              color: read
                  ? (onDark ? const Color(0xFF90CAF9) : AppColors.primary500)
                  : color,
            ),
        ],
      ],
    );
  }
}
