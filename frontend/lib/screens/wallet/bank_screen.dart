import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/api_client.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankName.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.get('/wallet/bank', auth: true)
          as Map<String, dynamic>;
      final bank = data['bank'] as Map?;
      if (bank != null) {
        _bankName.text = bank['bankName']?.toString() ?? '';
        _accountName.text = bank['accountName']?.toString() ?? '';
        _accountNumber.text = bank['accountNumber']?.toString() ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.put('/wallet/bank', auth: true, body: {
        'bankName': _bankName.text.trim(),
        'accountName': _accountName.text.trim(),
        'accountNumber': _accountNumber.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account saved')),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Bank account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const SoftText(
                  'Withdrawals are sent to this account. Use your real Nigerian bank details.',
                  size: 14,
                ),
                const SizedBox(height: 20),
                const FieldLabel('Bank name'),
                AppTextField(hint: 'e.g. GTBank', controller: _bankName),
                const SizedBox(height: 12),
                const FieldLabel('Account name'),
                AppTextField(hint: 'Name on the account', controller: _accountName),
                const SizedBox(height: 12),
                const FieldLabel('Account number'),
                AppTextField(
                  hint: '10 digits',
                  controller: _accountNumber,
                  keyboardType: TextInputType.number,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save bank account',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }
}
