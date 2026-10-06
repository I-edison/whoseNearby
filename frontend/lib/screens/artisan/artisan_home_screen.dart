import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/artisan_profile_service.dart';
import '../../services/job_service.dart';
import '../../services/wallet_service.dart';
import '../../services/api_client.dart';

class ArtisanHomeScreen extends StatefulWidget {
  const ArtisanHomeScreen({super.key});

  @override
  State<ArtisanHomeScreen> createState() => _ArtisanHomeScreenState();
}

class _ArtisanHomeScreenState extends State<ArtisanHomeScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _jobs = [];
  double _balance = 0;
  bool _loading = true;
  bool? _available;
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      final profile = await ArtisanProfileService.instance.getMine();
      if (profile == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/artisan-onboarding');
        return;
      }
      final jobs = await JobService.instance.mine(as: 'artisan');
      double bal = 0;
      try {
        final w = await WalletService.instance.getWallet();
        bal = (w['balance'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _jobs = jobs;
        _balance = bal;
        _available = profile['isAvailable'] == true;
        _loading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailable(bool v) async {
    setState(() => _available = v);
    try {
      await ArtisanProfileService.instance.setAvailability(v);
    } catch (_) {
      setState(() => _available = !v);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = _profile?['businessName']?.toString() ?? 'Artisan';
    final skill = _profile?['primarySkill']?.toString() ?? '';
    final rating = (_profile?['ratingAvg'] as num?)?.toStringAsFixed(1) ?? '—';
    final jobsDone = _profile?['jobsDone'] ?? 0;
    final active = _jobs.where((j) {
      final s = j['status']?.toString();
      return s == 'NEGOTIATING' || s == 'IN_PROGRESS' || s == 'OPEN';
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Artisan'),
        actions: [
          IconButton(onPressed: _boot, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _boot,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(
                    letter: name.isNotEmpty ? name[0] : 'A',
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SoftText(skill, size: 13),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Available for jobs',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                value: _available ?? true,
                activeThumbColor: AppColors.primary700,
                onChanged: _toggleAvailable,
              ),
              const SizedBox(height: 8),
              BalanceCard(
                name: 'Wallet',
                masked: 'Available',
                balance: _fmt.format(_balance),
                extra: Row(
                  children: [
                    _Stat('$jobsDone', 'Jobs'),
                    const SizedBox(width: 8),
                    _Stat(rating, 'Rating'),
                    const SizedBox(width: 8),
                    _Stat('${active.length}', 'Active'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Open job inbox',
                icon: Icons.inbox_outlined,
                onPressed: () => Navigator.pushNamed(context, '/job-inbox')
                    .then((_) => _boot()),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Browse open jobs',
                onPressed: () => Navigator.pushNamed(context, '/open-jobs')
                    .then((_) => _boot()),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Edit profile',
                onPressed: () =>
                    Navigator.pushNamed(context, '/artisan-onboarding')
                        .then((_) => _boot()),
              ),
              const SizedBox(height: 24),
              SectionHeader(
                'Active jobs',
                trailing: AppChip(
                  label: '${active.length}',
                  variant: ChipVariant.green,
                ),
              ),
              if (active.isEmpty)
                const SoftText('No active jobs right now.')
              else
                ...active.take(5).map((j) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: j['id'] as String,
                      ),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    j['title']?.toString() ?? 'Job',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SoftText(j['status']?.toString() ?? '', size: 12),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
