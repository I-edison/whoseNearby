import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/job_service.dart';
import '../../services/api_client.dart';

class JobInboxScreen extends StatefulWidget {
  const JobInboxScreen({super.key});

  @override
  State<JobInboxScreen> createState() => _JobInboxScreenState();
}

class _JobInboxScreenState extends State<JobInboxScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

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
      final jobs = await JobService.instance.mine(as: 'artisan');
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
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
        _error = 'Could not load jobs';
        _loading = false;
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return AppColors.primary700;
      case 'COMPLETED':
        return AppColors.inkSoft;
      case 'NEGOTIATING':
        return AppColors.accent;
      default:
        return AppColors.inkFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Job inbox'),
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
              : _jobs.isEmpty
                  ? const Center(
                      child: SoftText('No jobs yet. Clients will find you nearby.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final j = _jobs[i];
                          final client = j['client'] as Map<String, dynamic>?;
                          final status = j['status']?.toString() ?? '';
                          final amount = j['agreedAmount'];
                          final code = j['completionCode']?.toString();
                          return GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: j['id'] as String,
                            ).then((_) => _load()),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          j['title']?.toString() ?? 'Job',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      AppChip(
                                        label: status,
                                        variant: status == 'IN_PROGRESS'
                                            ? ChipVariant.green
                                            : ChipVariant.line,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SoftText(
                                    [
                                      j['category']?.toString(),
                                      j['whenNeeded']?.toString(),
                                      client?['fullName']?.toString(),
                                    ].where((e) => e != null && e.isNotEmpty).join(' · '),
                                    size: 13,
                                  ),
                                  if (amount != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _fmt.format((amount as num).toDouble()),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                  ],
                                  if (status == 'IN_PROGRESS' && code != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary050,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SoftText(
                                            'Completion code — share when done',
                                            size: 12,
                                          ),
                                          Text(
                                            code,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 4,
                                              color: AppColors.primary700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Open chat ›',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary700,
                                    ),
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
