import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/wallet_service.dart';
import '../../services/api_client.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String pin = '';
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    if (pin.length != 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await WalletService.instance.setPin(pin);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        pin = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save PIN';
        pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — aligned back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  const AppBackButton(),
                  const Spacer(),
                  Text(
                    'Wallet PIN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // balance the back button
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary050,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 28,
                        color: AppColors.primary700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Secure your wallet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SoftText(
                      'Set a 4-digit PIN to send and hold money safely.',
                      size: 15,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Centered PIN dots
                    Center(child: PinDots(filled: pin.length)),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    else
                      SizedBox(
                        height: 320,
                        child: NumPad(
                          onKey: (k) {
                            if (pin.length < 4) {
                              setState(() => pin += k);
                              if (pin.length == 4) _save();
                            }
                          },
                          onBackspace: () {
                            if (pin.isNotEmpty) {
                              setState(
                                () => pin = pin.substring(0, pin.length - 1),
                              );
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
