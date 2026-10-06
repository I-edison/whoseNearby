import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';
import '../../services/payment_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  double _balance = 0;
  Map<String, dynamic>? _bank;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final w = await PaymentService.instance.getWallet();
      final bank = await PaymentService.instance.getBank();
      if (!mounted) return;
      setState(() {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _bank = bank;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    final pin = _pinCtrl.text.trim();
    if (amount == null || amount < 100) {
      setState(() => _error = 'Enter at least ₦100');
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit PIN');
      return;
    }
    if (_bank == null) {
      setState(() => _error = 'Add a bank account first');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PaymentService.instance.withdraw(amount: amount, pin: pin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Withdrawal requested to ${_bank!['bankName']} · ${_bank!['accountNumber']}',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Withdrawal failed');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Withdraw'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SoftText('Available to withdraw', size: 13),
                      Text(
                        _fmt.format(_balance),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SoftText(
                        'Money still on hold for active jobs cannot be withdrawn until the client confirms.',
                        size: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_bank == null) ...[
                  const SoftText('Add your bank account to receive money.', size: 14),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Add bank account',
                    onPressed: () => Navigator.pushNamed(context, '/bank').then((_) => _load()),
                  ),
                ] else ...[
                  SoftText(
                    'To: ${_bank!['accountName']} · ${_bank!['bankName']} · ${_bank!['accountNumber']}',
                    size: 13,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/bank').then((_) => _load()),
                    child: const Text('Change bank'),
                  ),
                ],
                const SizedBox(height: 12),
                const FieldLabel('Amount (₦)'),
                AppTextField(
                  controller: _amountCtrl,
                  hint: 'e.g. 5000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const FieldLabel('Wallet PIN'),
                AppTextField(
                  controller: _pinCtrl,
                  hint: '4 digits',
                  keyboardType: TextInputType.number,
                  obscure: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Withdraw',
                  loading: _submitting,
                  onPressed: _submitting || _bank == null ? null : _submit,
                ),
              ],
            ),
    );
  }
}
