import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class OpenJobsScreen extends StatefulWidget {
  const OpenJobsScreen({super.key});

  @override
  State<OpenJobsScreen> createState() => _OpenJobsScreenState();
}

class _OpenJobsScreenState extends State<OpenJobsScreen> {
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
      final me = await AuthService.instance.me();
      final skill = me?['artisanProfile'] is Map
          ? (me!['artisanProfile'] as Map)['primarySkill']?.toString()
          : null;
      final data = await ApiClient.instance.get(
        '/jobs/open',
        auth: true,
        query: {if (skill != null && skill.isNotEmpty) 'skill': skill},
      ) as Map<String, dynamic>;
      final list = (data['jobs'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _jobs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
        _error = 'Could not load open jobs';
        _loading = false;
      });
    }
  }

  Future<void> _accept(String jobId) async {
    try {
      await ApiClient.instance.post('/jobs/$jobId/assign', auth: true, body: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You joined this job — open chat')),
      );
      Navigator.pushNamed(context, '/chat', arguments: jobId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Open jobs'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: SoftText(_error!))
              : _jobs.isEmpty
                  ? const Center(
                      child: SoftText(
                        'No open jobs for your skill right now. Check back soon.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final j = _jobs[i];
                          final client = j['client'] as Map?;
                          final budget = j['budgetMin'] ?? j['budgetMax'];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  j['title']?.toString() ?? 'Job',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SoftText(
                                  [
                                    j['category']?.toString(),
                                    j['whenNeeded']?.toString(),
                                    client?['area']?.toString() ?? client?['city']?.toString(),
                                  ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                                  size: 13,
                                ),
                                if (budget != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _fmt.format((budget as num).toDouble()),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  label: 'Accept & chat',
                                  onPressed: () => _accept(j['id'] as String),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
