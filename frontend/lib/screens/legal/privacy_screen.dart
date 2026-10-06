import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Privacy policy',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),
          const SoftText(
            'We collect your name, phone or email, approximate location (to sort nearby artisans), chat for jobs, and wallet transaction records.\n\n'
            'We do not sell your personal data.\n\n'
            'Card payments are processed by Paystack when enabled; we store balances and references, not full card numbers.\n\n'
            'You can request account deletion via Support.',
            size: 14,
          ),
        ],
      ),
    );
  }
}
