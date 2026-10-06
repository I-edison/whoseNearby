import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in all required fields');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.register(
        fullName: name,
        identifier: id,
        password: pass,
        city: 'Lagos',
        area: 'Ikeja',
      );
      final otpRes = await AuthService.instance.requestOtp(id);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/otp',
        arguments: {
          'target': id,
          'next': '/role',
          'demoCode': otpRes['code']?.toString(),
        },
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Cannot reach server. Is the API running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Create your account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const SoftText(
                'Your neighbour might be your next artisan — or client.',
                size: 15,
              ),
              const SizedBox(height: 28),
              const FieldLabel('Full name'),
              AppTextField(hint: 'Tunde Balogun', controller: _nameCtrl),
              const SizedBox(height: 16),
              const FieldLabel('Email or phone'),
              AppTextField(
                hint: 'you@email.com or 0801 234 5678',
                controller: _idCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Password'),
              AppTextField(
                hint: '••••••••',
                controller: _passCtrl,
                obscure: true,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Confirm password'),
              AppTextField(
                hint: '••••••••',
                controller: _confirmCtrl,
                obscure: true,
              ),
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
              PrimaryButton(
                label: 'Create account',
                loading: _loading,
                onPressed: _loading ? null : _register,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log in',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
