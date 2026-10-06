import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/artisan_profile_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class ArtisanOnboardingScreen extends StatefulWidget {
  const ArtisanOnboardingScreen({super.key});

  @override
  State<ArtisanOnboardingScreen> createState() => _ArtisanOnboardingScreenState();
}

class _ArtisanOnboardingScreenState extends State<ArtisanOnboardingScreen> {
  final _biz = TextEditingController();
  final _skill = TextEditingController();
  final _bio = TextEditingController();
  final _rate = TextEditingController();
  bool _loading = false;
  String? _error;
  final _skills = [
    'Electrician',
    'Plumber',
    'Barber',
    'Carpenter',
    'Painter',
    'AC Repair',
    'Cleaner',
    'Welder',
    'Tailor',
    'Mechanic',
    'Mason',
    'Other',
  ];

  @override
  void dispose() {
    _biz.dispose();
    _skill.dispose();
    _bio.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _biz.text.trim();
    final skill = _skill.text.trim();
    if (name.length < 2 || skill.length < 2) {
      setState(() => _error = 'Business name and skill are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rate = double.tryParse(_rate.text.trim());
      await ArtisanProfileService.instance.save(
        businessName: name,
        primarySkill: skill,
        bio: _bio.text.trim(),
        hourlyRate: rate,
      );
      await AuthService.instance.me();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/artisan-home');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save profile');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,title: const Text('Become an artisan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up your profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const SoftText(
              'Clients nearby will see this when they search for help.',
              size: 14,
            ),
            const SizedBox(height: 24),
            const FieldLabel('Business / trade name'),
            AppTextField(hint: "e.g. Ada's Plumbing", controller: _biz),
            const SizedBox(height: 16),
            const FieldLabel('Skill you offer'),
            const SoftText('Clients will find you when they need this skill', size: 12),
            const SizedBox(height: 8),
            AppTextField(hint: 'Your main trade', controller: _skill),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills
                  .map(
                    (s) => GestureDetector(
                      onTap: () => setState(() => _skill.text = s),
                      child: AppChip(
                        label: s,
                        variant: _skill.text == s
                            ? ChipVariant.dark
                            : ChipVariant.line,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Hourly rate (optional)'),
            AppTextField(
              hint: '3500',
              controller: _rate,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Bio'),
            AppTextField(
              hint: 'Years of experience, areas you cover…',
              controller: _bio,
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save & open inbox',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
