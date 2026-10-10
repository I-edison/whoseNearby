import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';
import 'home_feed_screen.dart';
import '../wallet/wallet_screen.dart';
import '../chat/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../job/notifications_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  Key _walletKey = UniqueKey();
  Key _messagesKey = UniqueKey();
  Key _alertsKey = UniqueKey();

  bool _chatDot = false;
  bool _walletDot = false;
  bool _alertsDot = false;

  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
    _badgeTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshBadges(),
    );
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadges() async {
    try {
      // Chat unread
      bool chat = false;
      try {
        final conv = await ApiClient.instance.get(
          '/chat/conversations',
          auth: true,
        ) as Map<String, dynamic>;
        final list = (conv['conversations'] as List?) ?? [];
        chat = list.any((c) => ((c as Map)['unread'] as num?)?.toInt() ?? 0 > 0);
      } catch (_) {}

      // Notifications unread → alerts + wallet-related
      bool alerts = false;
      bool wallet = false;
      try {
        final data = await ApiClient.instance.get(
          '/notifications',
          auth: true,
        ) as Map<String, dynamic>;
        final list = (data['notifications'] as List?) ?? [];
        for (final n in list) {
          final m = Map<String, dynamic>.from(n as Map);
          if (m['read'] == true) continue;
          final type = (m['type']?.toString() ?? '').toLowerCase();
          if (type.contains('pay') ||
              type.contains('wallet') ||
              type.contains('fund') ||
              type.contains('escrow')) {
            wallet = true;
          } else {
            alerts = true;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _chatDot = chat;
        _walletDot = wallet;
        _alertsDot = alerts;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeFeedScreen(),
      WalletScreen(key: _walletKey),
      MessagesScreen(key: _messagesKey),
      NotificationsScreen(key: _alertsKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) {
          setState(() {
            if (i == 1) {
              _walletKey = UniqueKey();
              _walletDot = false; // clear when opened
            }
            if (i == 2) {
              _messagesKey = UniqueKey();
              _chatDot = false;
            }
            if (i == 3) {
              _alertsKey = UniqueKey();
              _alertsDot = false;
            }
            index = i;
          });
          // Re-check after a short delay (marks as read on those screens)
          Future.delayed(const Duration(seconds: 2), _refreshBadges);
        },
        items: [
          const BottomNavItem(Icons.home_outlined, 'Home',
              activeIcon: Icons.home_rounded),
          BottomNavItem(
            Icons.account_balance_wallet_outlined,
            'Wallet',
            activeIcon: Icons.account_balance_wallet_rounded,
            showDot: _walletDot,
          ),
          BottomNavItem(
            Icons.chat_bubble_outline_rounded,
            'Chat',
            activeIcon: Icons.chat_bubble_rounded,
            showDot: _chatDot,
          ),
          BottomNavItem(
            Icons.notifications_outlined,
            'Alerts',
            activeIcon: Icons.notifications_rounded,
            showDot: _alertsDot,
          ),
          const BottomNavItem(Icons.person_outline_rounded, 'Profile',
              activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }
}