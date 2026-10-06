import 'package:flutter/material.dart';
import '../../widgets/app_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeFeedScreen(),
      WalletScreen(key: _walletKey),
      MessagesScreen(key: _messagesKey),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) {
          setState(() {
            // Force wallet / messages to reload fresh balance & threads
            if (i == 1) _walletKey = UniqueKey();
            if (i == 2) _messagesKey = UniqueKey();
            index = i;
          });
        },
        items: const [
          BottomNavItem(Icons.home_outlined, 'Home',
              activeIcon: Icons.home_rounded),
          BottomNavItem(Icons.account_balance_wallet_outlined, 'Wallet',
              activeIcon: Icons.account_balance_wallet_rounded),
          BottomNavItem(Icons.chat_bubble_outline_rounded, 'Chat',
              activeIcon: Icons.chat_bubble_rounded),
          BottomNavItem(Icons.notifications_outlined, 'Alerts',
              activeIcon: Icons.notifications_rounded),
          BottomNavItem(Icons.person_outline_rounded, 'Profile',
              activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }
}
