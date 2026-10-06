import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/job_service.dart';
import '../../services/api_client.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  String? _jobId;
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_jobId == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      return;
    }
    setState(() => _loading = true);
    try {
      await JobService.instance.rate(
        jobId: _jobId!,
        stars: _stars,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary900.withValues(alpha: 0.55),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                    }
                  },
                  icon: const Icon(Icons.close, size: 22),
                ),
              ),
              Text(
                'Job complete 🎉',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText('How was your experience?', size: 14),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  return IconButton(
                    onPressed: () => setState(() => _stars = n),
                    icon: Icon(
                      n <= _stars ? Icons.star : Icons.star_border,
                      color: AppColors.accent,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              AppTextField(
                hint: 'Share a few words about the job…',
                controller: _commentCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit rating',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'Skip for now',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (_) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
