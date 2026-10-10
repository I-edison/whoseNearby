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
  double? _selectedQuick;

  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  List<double> get _quickAmounts {
    final caps = <double>[500, 1000, 2000, 5000, 10000];
    return caps.where((a) => a <= _balance).toList();
  }

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

  void _pickAmount(double a) {
    setState(() {
      _selectedQuick = a;
      _amountCtrl.text = a.toStringAsFixed(0);
      _error = null;
    });
  }

  void _pickMax() {
    if (_balance < 100) return;
    final max = _balance.floorToDouble();
    setState(() {
      _selectedQuick = null;
      _amountCtrl.text = max.toStringAsFixed(0);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final pin = _pinCtrl.text.trim();

    if (amount == null || amount < 100) {
      setState(() => _error = 'Enter at least ₦100');
      return;
    }
    if (amount > _balance) {
      setState(() => _error = 'Amount is more than your balance');
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
            '₦${amount.toStringAsFixed(0)} sent to ${_bank!['bankName']} · ${_bank!['accountNumber']}',
          ),
          backgroundColor: AppColors.primary700,
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
                // Balance
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SoftText('Available to withdraw', size: 13),
                      const SizedBox(height: 4),
                      Text(
                        _fmt.format(_balance),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SoftText(
                        'Funds on hold for active jobs are not included.',
                        size: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bank
                if (_bank == null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Where should we send the money?',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const SoftText(
                          'Add your bank account once — next withdrawals are one tap.',
                          size: 13,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Add bank account',
                          onPressed: () => Navigator.pushNamed(context, '/bank')
                              .then((_) => _load()),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary050,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: AppColors.primary700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bank!['accountName']?.toString() ?? 'Account',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_bank!['bankName']} · ${_bank!['accountNumber']}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/bank')
                              .then((_) => _load()),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Text(
                  'Amount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                // Quick amounts (Bolt-style)
                if (_quickAmounts.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._quickAmounts.map((a) {
                        final on = _selectedQuick == a;
                        return GestureDetector(
                          onTap: () => _pickAmount(a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: on
                                  ? AppColors.primary700
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: on
                                    ? AppColors.primary700
                                    : AppColors.line,
                              ),
                            ),
                            child: Text(
                              '₦${a.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: on ? Colors.white : AppColors.ink,
                              ),
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _pickMax,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            'Max',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),
                AppTextField(
                  controller: _amountCtrl,
                  hint: 'Or enter amount',
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 16),
                const FieldLabel('Wallet PIN'),
                AppTextField(
                  controller: _pinCtrl,
                  hint: '4 digits',
                  keyboardType: TextInputType.number,
                  obscure: true,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: GoogleFonts.plusJakartaSans(color: AppColors.danger),
                  ),
                ],

                const SizedBox(height: 24),
                PrimaryButton(
                  label: _amountCtrl.text.trim().isEmpty
                      ? 'Withdraw'
                      : 'Withdraw ₦${_amountCtrl.text.trim()}',
                  loading: _submitting,
                  onPressed: _submitting || _bank == null ? null : _submit,
                ),
              ],
            ),
    );
  }
}