import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';
import '../../services/job_service.dart';
import '../../services/payment_service.dart';

class ConfirmPayScreen extends StatefulWidget {
  const ConfirmPayScreen({super.key});

  @override
  State<ConfirmPayScreen> createState() => _ConfirmPayScreenState();
}

class _ConfirmPayScreenState extends State<ConfirmPayScreen> {
  String pin = '';
  bool _loading = false;
  bool _funding = false;
  String? _error;
  double _balance = 0;
  bool _hasPin = false;
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  Map<String, dynamic>? get _args {
    return ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  double get _amount => (_args?['amount'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWallet());
  }

  Future<void> _refreshWallet() async {
    try {
      final w = await PaymentService.instance.getWallet();
      if (!mounted) return;
      setState(() {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _hasPin = w['hasPin'] == true;
      });
    } catch (_) {}
  }

  Future<void> _fundEnough() async {
    final need = _amount - _balance;
    final topUp = need < 100 ? 100.0 : need;
    setState(() {
      _funding = true;
      _error = null;
    });
    try {
      final init = await PaymentService.instance.startPaystackFund(topUp);
      final ref = init['reference']?.toString() ?? '';
      final demo = init['demo'] == true;
      final url = init['authorization_url']?.toString();

      if (!demo && url != null && url.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pay ₦${topUp.toStringAsFixed(0)} here: $url')),
        );
        final paid = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add money (Paystack)'),
            content: Text(
              'Complete payment in your browser, then tap I have paid.\n\n'
              'Amount: ${_fmt.format(topUp)}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I have paid')),
            ],
          ),
        );
        if (paid == true) {
          await PaymentService.instance.verifyPaystack(ref);
          await _refreshWallet();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wallet funded')),
          );
        }
      } else {
        await PaymentService.instance.completeDemoFund(ref);
        await _refreshWallet();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${_fmt.format(topUp)} (demo / test)')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not fund wallet');
    } finally {
      if (mounted) setState(() => _funding = false);
    }
  }

  Future<void> _submit() async {
    if (pin.length != 4 || _args == null) return;
    if (!_hasPin) {
      setState(() => _error = 'Set a wallet PIN first (Wallet → PIN)');
      return;
    }
    if (_balance < _amount) {
      setState(() => _error = 'Not enough balance. Tap Add money first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await JobService.instance.start(
        jobId: _args!['jobId'] as String,
        amount: _amount,
        pin: pin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment held safely until the job is done')),
      );
      Navigator.pushReplacementNamed(
        context,
        '/confirm-job',
        arguments: _args!['jobId'] as String,
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        pin = '';
      });
    } catch (_) {
      setState(() {
        _error = 'Payment failed';
        pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tapDigit(String d) {
    if (pin.length >= 4) return;
    setState(() {
      pin += d;
      _error = null;
    });
    if (pin.length == 4) _submit();
  }

  @override
  Widget build(BuildContext context) {
    final peer = _args?['peer']?.toString() ?? 'Artisan';
    final title = _args?['title']?.toString() ?? 'Job';
    final shortfall = _amount > _balance ? _amount - _balance : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(),
              const SizedBox(height: 12),
              Text(
                'Confirm & pay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SoftText('$title · $peer', size: 14),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt.format(_amount),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SoftText(
                      'Held safely until you confirm the job is complete. The artisan is paid only after you enter their completion code.',
                      size: 13,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SoftText(
                            'Wallet: ${_fmt.format(_balance)}',
                            size: 13,
                          ),
                        ),
                        if (shortfall > 0)
                          Text(
                            'Need ${_fmt.format(shortfall)} more',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (shortfall > 0) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _funding ? 'Adding money…' : 'Add money with Paystack',
                  loading: _funding,
                  onPressed: _funding ? null : _fundEnough,
                ),
              ],
              if (!_hasPin) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Set wallet PIN first',
                  onPressed: () => Navigator.pushNamed(context, '/pin-setup')
                      .then((_) => _refreshWallet()),
                ),
              ],
              const SizedBox(height: 20),
              const FieldLabel('Enter 4-digit PIN to hold payment'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary700 : AppColors.line,
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                _PinPad(onDigit: _tapDigit, onBack: () {
                  if (pin.isEmpty) return;
                  setState(() => pin = pin.substring(0, pin.length - 1));
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBack;
  const _PinPad({required this.onDigit, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => k == '⌫' ? onBack() : onDigit(k),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              k,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
