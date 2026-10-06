import 'api_client.dart';

/// Unified wallet money movement (Paystack primary).
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> getWallet() async {
    return await _api.get('/wallet', auth: true) as Map<String, dynamic>;
  }

  /// Start Paystack top-up. Returns reference + authorization_url (or demo).
  Future<Map<String, dynamic>> startPaystackFund(double amountNaira) async {
    return await _api.post(
      '/wallet/paystack/initialize',
      auth: true,
      body: {'amount': amountNaira},
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyPaystack(String reference) async {
    return await _api.post(
      '/wallet/paystack/verify',
      auth: true,
      body: {'reference': reference},
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeDemoFund(String reference) async {
    return await _api.post(
      '/wallet/paystack/demo-complete',
      auth: true,
      body: {'reference': reference},
    ) as Map<String, dynamic>;
  }

  Future<double> withdraw({required double amount, required String pin}) async {
    final data = await _api.post('/wallet/withdraw', auth: true, body: {
      'amount': amount,
      'pin': pin,
    }) as Map<String, dynamic>;
    return (data['balance'] as num).toDouble();
  }

  Future<void> saveBank({
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? bankCode,
  }) async {
    await _api.put('/wallet/bank', auth: true, body: {
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      if (bankCode != null) 'bankCode': bankCode,
    });
  }

  Future<Map<String, dynamic>?> getBank() async {
    final data = await _api.get('/wallet/bank', auth: true) as Map<String, dynamic>;
    return data['bank'] as Map<String, dynamic>?;
  }
}
