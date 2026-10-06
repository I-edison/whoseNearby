import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/register_screen.dart';
import 'screens/onboarding/role_select_screen.dart';
import 'screens/onboarding/otp_screen.dart';
import 'screens/onboarding/location_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/home/artisan_detail_screen.dart';
import 'screens/home/search_screen.dart';
import 'screens/chat/messages_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/wallet/pin_setup_screen.dart';
import 'screens/wallet/confirm_pay_screen.dart';
import 'screens/wallet/escrow_screen.dart';
import 'screens/job/confirm_job_screen.dart';
import 'screens/job/rate_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/artisan/artisan_home_screen.dart';
import 'screens/artisan/artisan_onboarding_screen.dart';
import 'screens/artisan/job_inbox_screen.dart';
import 'services/notification_service.dart';
import 'screens/extra/post_job_screen.dart';
import 'screens/legal/terms_screen.dart';
import 'screens/legal/privacy_screen.dart';
import 'screens/legal/support_screen.dart';
import 'screens/artisan/open_jobs_screen.dart';
import 'screens/wallet/bank_screen.dart';
import 'screens/wallet/withdraw_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    await AppNotificationService.instance.init();
    AppNotificationService.instance.startPolling();
  } catch (_) {}
  runApp(const WhoseNearbyApp());
}

class WhoseNearbyApp extends StatelessWidget {
  const WhoseNearbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhoseNearby',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/role': (_) => const RoleSelectScreen(),
        '/otp': (_) => const OtpScreen(),
        '/location': (_) => const LocationScreen(),
        '/home': (_) => const HomeShell(),
        '/artisan': (_) => const ArtisanDetailScreen(),
        '/search': (_) => const SearchScreen(),
        '/messages': (_) => const MessagesScreen(),
        '/chat': (_) => const ChatScreen(),
        '/wallet': (_) => const WalletScreen(),
        '/pin-setup': (_) => const PinSetupScreen(),
        '/confirm-pay': (_) => const ConfirmPayScreen(),
        '/escrow': (_) => const EscrowScreen(),
        '/confirm-job': (_) => const ConfirmJobScreen(),
        '/rate': (_) => const RateScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/artisan-home': (_) => const ArtisanHomeScreen(),
        '/artisan-onboarding': (_) => const ArtisanOnboardingScreen(),
        '/job-inbox': (_) => const JobInboxScreen(),
        '/post-job': (_) => const PostJobScreen(),
        '/terms': (_) => const TermsScreen(),
        '/privacy': (_) => const PrivacyScreen(),
        '/support': (_) => const SupportScreen(),
        '/open-jobs': (_) => const OpenJobsScreen(),
        '/bank': (_) => const BankScreen(),
        '/withdraw': (_) => const WithdrawScreen(),
      },
    );
  }
}
