import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Terms of use'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'WhoseNearby Terms',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),
          const SoftText(
            '1. WhoseNearby connects clients with local artisans. We are a marketplace, not the person doing the work.\n\n'
            '2. Money paid for a job is held safely until you confirm the job is complete with the code, or until a dispute is resolved.\n\n'
            '3. Be honest. No fraud, harassment, or illegal jobs.\n\n'
            '4. Artisans are independent — not employees of WhoseNearby.\n\n'
            '5. In beta, OTP and wallet funding may use demo mode. Production uses real SMS and Paystack when configured.\n\n'
            'By using the app you agree to these terms.',
            size: 14,
          ),
        ],
      ),
    );
  }
}
