import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  String? _userName;
  bool _loading = true;
  String? _error;

  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

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
      final user = await AuthService.instance.currentUser();
      final wallet = await WalletService.instance.getWallet();
      if (!mounted) return;
      setState(() {
        _userName = user?['fullName'] as String?;
        _wallet = wallet;
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
        _error = 'Could not load wallet';
        _loading = false;
      });
    }
  }

  Future<void> _fund() async {
    final amount = await _askFundAmount();
    if (amount == null || !mounted) return;
    final provider = await _pickPayProvider();
    if (provider == null || !mounted) return;
    try {
      if (provider == 'bachs') {
        final init = await ApiClient.instance.post(
          '/wallet/bachs/initialize',
          auth: true,
          body: {'amount': amount},
        ) as Map<String, dynamic>;
        final url = init['checkout_url']?.toString() ??
            init['authorization_url']?.toString() ?? '';
        final checkoutId = init['checkoutId']?.toString() ?? '';
        if (url.isEmpty) {
          throw ApiException(400, init['error']?.toString() ?? 'Bachs checkout failed');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open Bachs to pay: $url')),
        );
        final paid = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pay with Bachs'),
            content: Text(
              'Complete payment in the browser, then tap I have paid.\n\n'
              'Amount: ₦${amount.toStringAsFixed(0)}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I have paid')),
            ],
          ),
        );
        if (paid == true && checkoutId.isNotEmpty) {
          await ApiClient.instance.post(
            '/wallet/bachs/verify',
            auth: true,
            body: {'checkoutId': checkoutId},
          );
          await _load();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bachs payment verified')),
          );
        }
        return;
      }

      final init = await ApiClient.instance.post(
        '/wallet/paystack/initialize',
        auth: true,
        body: {'amount': amount},
      ) as Map<String, dynamic>;
      final ref = init['reference']?.toString() ?? '';
      final demo = init['demo'] == true || provider == 'demo';
      final url = init['authorization_url']?.toString();

      if (!demo && url != null && url.isNotEmpty) {
        if (!mounted) return;
        final paid = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pay with Paystack'),
            content: Text(
              '1. Open the payment page\n'
              '2. Complete payment with card/USSD\n'
              '3. Come back and tap "I have paid"\n\n'
              'Amount: ₦${amount.toStringAsFixed(0)}\nRef: $ref',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Best-effort open in browser (web / external)
                  // ignore: unawaited_futures
                  // Using platform default via Uri — user can also copy link from snackbar
                  Navigator.pop(ctx, true);
                },
                child: const Text('I have paid'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pay here: $url')),
        );
        if (paid == true) {
          await ApiClient.instance.post(
            '/wallet/paystack/verify',
            auth: true,
            body: {'reference': ref},
          );
          await _load();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verified — balance updated')),
          );
        }
        return;
      }

      // Demo path when Paystack secret is not set
      await ApiClient.instance.post(
        '/wallet/paystack/demo-complete',
        auth: true,
        body: {'reference': ref},
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ₦${amount.toStringAsFixed(0)} (demo). Add PAYSTACK_SECRET_KEY for real card payments.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start top-up')),
      );
    }
  }


  Future<String?> _pickPayProvider() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Paystack'),
              subtitle: const Text('Card, USSD, bank — recommended'),
              onTap: () => Navigator.pop(ctx, 'paystack'),
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Demo credit'),
              subtitle: const Text('Test only — no real money'),
              onTap: () => Navigator.pop(ctx, 'demo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _askFundAmount() async {
    final ctrl = TextEditingController(text: '5000');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add money'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (₦)',
            hintText: '5000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
              if (v == null || v < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter at least ₦100')),
                );
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0;
    final txs = (_wallet?['transactions'] as List?) ?? [];
    final hasPin = _wallet?['hasPin'] == true;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        automaticallyImplyLeading: false,
        title: const Text('Wallet'),
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
                      const SizedBox(height: 12),
                      SecondaryButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BalanceCard(
                          name: _userName ?? '',
                          masked: hasPin ? 'PIN set' : 'No PIN yet',
                          balance: _fmt.format(balance),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickAction(Icons.add, 'Fund', onTap: _fund),
                            _QuickAction(
                              Icons.south_west,
                              'Withdraw',
                              onTap: () => Navigator.pushNamed(context, '/withdraw')
                                  .then((_) => _load()),
                            ),
                            _QuickAction(
                              Icons.lock_outline,
                              'On hold',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/escrow')
                                      .then((_) => _load()),
                            ),
                            _QuickAction(
                              Icons.account_balance_outlined,
                              'Bank',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/bank')
                                      .then((_) => _load()),
                            ),
                            _QuickAction(
                              Icons.pin_outlined,
                              hasPin ? 'PIN set' : 'Set PIN',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/pin-setup')
                                      .then((_) => _load()),
                            ),
                          ],
                        ),
                        if ((_wallet?['escrow'] as Map?)?['heldTotal'] != null &&
                            ((_wallet!['escrow'] as Map)['heldTotal'] as num) > 0) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/escrow'),
                            child: AppCard(
                              color: AppColors.accentSoft,
                              borderColor: AppColors.accent.withValues(alpha: 0.35),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline,
                                      color: AppColors.accent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'In escrow',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SoftText(
                                          'Tap to view held funds',
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _fmt.format(
                                      ((_wallet!['escrow'] as Map)['heldTotal'] as num)
                                          .toDouble(),
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        const FieldLabel('Recent activity'),
                        if (txs.isEmpty)
                          const SoftText('No transactions yet')
                        else
                          ...txs.take(15).map((t) {
                            final m = t as Map<String, dynamic>;
                            final type = m['type']?.toString() ?? '';
                            final amount = (m['amount'] as num?)?.toDouble() ?? 0;
                            final isIn = type == 'FUND' || type == 'ESCROW_RELEASE';
                            final typeLabel = switch (type) {
                              'FUND' => 'Added money',
                              'ESCROW_HOLD' => 'Paid for a job (on hold)',
                              'ESCROW_RELEASE' => 'Received job payment',
                              'WITHDRAW' => 'Withdrawal',
                              'REFUND' => 'Refund',
                              _ => type,
                            };
                            return _Activity(
                              title: m['description']?.toString() ?? typeLabel,
                              subtitle: typeLabel,
                              amount:
                                  '${isIn ? '+' : '-'}${_fmt.format(amount)}',
                              green: isIn,
                              amber: type == 'ESCROW_HOLD',
                            );
                          }),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary050,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.primary700, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  final String title, subtitle, amount;
  final bool amber, green;
  const _Activity({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amber = false,
    this.green = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SoftText(subtitle, size: 12),
              ],
            ),
          ),
          if (amber)
            AppChip(label: amount, variant: ChipVariant.amber)
          else
            Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: green ? AppColors.primary700 : AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}
