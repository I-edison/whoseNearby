import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';

class EscrowScreen extends StatefulWidget {
  const EscrowScreen({super.key});

  @override
  State<EscrowScreen> createState() => _EscrowScreenState();
}

class _EscrowScreenState extends State<EscrowScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.get('/wallet/escrow', auth: true)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _data = data;
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
        _error = 'Could not load money on hold';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final heldTotal = (_data?['heldTotal'] as num?)?.toDouble() ?? 0;
    final incomingTotal = (_data?['incomingTotal'] as num?)?.toDouble() ?? 0;
    final held = (_data?['held'] as List?) ?? [];
    final incoming = (_data?['incoming'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Money on hold'),
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
                      const SizedBox(height: 12),
                      SecondaryButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      const SoftText(
                        'This is money waiting for a job to finish. It is safe — nobody can spend it until the client confirms the work is done.',
                        size: 14,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: 'You paid (waiting)',
                              amount: _fmt.format(heldTotal),
                              subtitle: 'Locked until you confirm',
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              label: 'You will receive',
                              amount: _fmt.format(incomingTotal),
                              subtitle: 'When client says job is done',
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const FieldLabel('Jobs you paid for (still waiting)'),
                      if (held.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: SoftText('Nothing waiting. When you pay for a job, it shows here until you confirm it is finished.'),
                        )
                      else
                        ...held.map((e) {
                          final m = e as Map<String, dynamic>;
                          return _EscrowTile(
                            title: m['peerName']?.toString() ?? 'Artisan',
                            subtitle: m['title']?.toString() ?? '',
                            amount: _fmt.format(
                              (m['amount'] as num?)?.toDouble() ?? 0,
                            ),
                            trailing: 'Waiting',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: m['jobId'] as String?,
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      const FieldLabel('Jobs you are doing (you get paid when client confirms)'),
                      if (incoming.isEmpty)
                        const SoftText('No jobs waiting for payment right now.')
                      else
                        ...incoming.map((e) {
                          final m = e as Map<String, dynamic>;
                          final code = m['completionCode']?.toString();
                          return _EscrowTile(
                            title: m['peerName']?.toString() ?? 'Client',
                            subtitle: code != null
                                ? '${m['title']} · Code $code'
                                : m['title']?.toString() ?? '',
                            amount: _fmt.format(
                              (m['amount'] as num?)?.toDouble() ?? 0,
                            ),
                            trailing: 'Awaiting confirm',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: m['jobId'] as String?,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, amount, subtitle;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          SoftText(subtitle, size: 11),
        ],
      ),
    );
  }
}

class _EscrowTile extends StatelessWidget {
  final String title, subtitle, amount, trailing;
  final VoidCallback? onTap;
  const _EscrowTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SoftText(subtitle, size: 12),
                    const SizedBox(height: 4),
                    AppChip(label: trailing, variant: ChipVariant.amber),
                  ],
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
