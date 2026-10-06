import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/job_service.dart';
import '../../services/api_client.dart';

class ConfirmJobScreen extends StatefulWidget {
  const ConfirmJobScreen({super.key});

  @override
  State<ConfirmJobScreen> createState() => _ConfirmJobScreenState();
}

class _ConfirmJobScreenState extends State<ConfirmJobScreen> {
  String? _jobId;
  String _code = '';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _job;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_jobId == null) {
      _jobId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_jobId != null) _load();
    }
  }

  Future<void> _load() async {
    try {
      final job = await JobService.instance.getById(_jobId!);
      if (!mounted) return;
      setState(() => _job = job);
    } catch (_) {}
  }

  Future<void> _complete() async {
    if (_code.length != 6 || _jobId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await JobService.instance.complete(jobId: _jobId!, code: _code);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/rate', arguments: _jobId);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not complete job');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (_job?['agreedAmount'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm job completion',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText(
                'Ask the artisan for their 6-digit completion code, then enter it below to release payment.',
                size: 14,
              ),
              const SizedBox(height: 24),
              const FieldLabel('Completion code'),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (v) => setState(() => _code = v.trim()),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                        color: AppColors.primary600, width: 1.5),
                  ),
                ),
              ),
              if (amount != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.primary050,
                  borderColor: AppColors.primary100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SoftText('Amount to release', size: 13),
                      Text(
                        '₦${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.primary700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Release payment',
                loading: _loading,
                onPressed: _loading || _code.length != 6 ? null : _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
