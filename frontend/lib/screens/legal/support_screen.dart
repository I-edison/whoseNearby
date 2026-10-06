import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Need help?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const SoftText(
            'For payment issues, disputes, or account problems, contact us:',
            size: 14,
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                const SoftText('support@whosenearby.app', size: 14),
                const SizedBox(height: 12),
                Text('WhatsApp', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                const SoftText('+234 800 000 0000 (replace with yours)', size: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Terms of use',
            onPressed: () => Navigator.pushNamed(context, '/terms'),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Privacy policy',
            onPressed: () => Navigator.pushNamed(context, '/privacy'),
          ),
        ],
      ),
    );
  }
}
