import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/media_service.dart';
import '../../services/chat_service.dart';
import '../../services/api_client.dart';
import '../../services/chat_socket.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    ChatSocket.instance.connect();
    _wsSub = ChatSocket.instance.events.listen((e) {
      if (e['type'] == 'conversation_updated' || e['type'] == 'message') {
        if (mounted) _loadQuiet();
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_loading) _loadQuiet();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiet() async {
    try {
      final list = await ChatService.instance.conversations();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ChatService.instance.conversations();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Messages'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SoftText(_error!),
                      SecondaryButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: SoftText('No conversations yet. Chat an artisan from Home.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          final letter =
                              c['peerLetter']?.toString() ?? 'A';
                          final peerAvatar = MediaService.resolveUrl(
                            c['peerAvatarUrl']?.toString(),
                          );
                          return InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: c['jobId'] as String,
                            ).then((_) => _load()),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  AppAvatar(
                                    letter: letter,
                                    size: 48,
                                    imageUrl: peerAvatar,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['peerName']?.toString() ?? 'Chat',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SoftText(
                                          c['lastMessage']?.toString() ??
                                              c['title']?.toString() ??
                                              '',
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppChip(
                                    label: c['status']?.toString() ?? '',
                                    variant: ChipVariant.line,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
