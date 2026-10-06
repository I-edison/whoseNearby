import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  String? _target;
  String? _nextRoute;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _hint; // demo code from API
  int _seconds = 60;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_target == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _target = args['target']?.toString();
        _nextRoute = args['next']?.toString() ?? '/role';
        _hint = args['demoCode']?.toString();
      } else if (args is String) {
        _target = args;
        _nextRoute = '/role';
      }
      _startTimer();
      // Request OTP if we landed here without a prior request
      if (_target != null && _hint == null) {
        _resend(silent: true);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 5 * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _resend({bool silent = false}) async {
    if (_target == null) return;
    if (!silent) setState(() => _resending = true);
    try {
      final data = await AuthService.instance.requestOtp(_target!);
      if (!mounted) return;
      setState(() {
        _hint = data['code']?.toString();
        _error = null;
      });
      _startTimer();
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code sent')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send code');
    } finally {
      if (mounted && !silent) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (_target == null) {
      setState(() => _error = 'Missing phone/email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.verifyOtp(target: _target!, code: code);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, _nextRoute ?? '/role');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Verification failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = _target ?? 'your number';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 24),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary050,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  color: AppColors.primary700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Verify it's you",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText('Enter the 6-digit code sent to', size: 15),
              const SizedBox(height: 4),
              Text(
                display,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.primary600,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
              if (_hint != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.primary050,
                  borderColor: AppColors.primary100,
                  padding: const EdgeInsets.all(12),
                  child: SoftText(
                    'Your code (dev only): $_hint — expires in a few minutes',
                    size: 13,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_seconds > 0)
                SoftText(
                  'Resend code in ${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                  size: 13,
                )
              else
                GestureDetector(
                  onTap: _resending ? null : () => _resend(),
                  child: Text(
                    _resending ? 'Sending…' : 'Resend code',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Verify & continue',
                loading: _loading,
                onPressed: _loading ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
