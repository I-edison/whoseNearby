import 'api_client.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> getWallet() async {
    return await _api.get('/wallet', auth: true) as Map<String, dynamic>;
  }

  Future<void> setPin(String pin) async {
    await _api.post('/wallet/pin', auth: true, body: {'pin': pin});
  }

  Future<double> fund(double amount) async {
    final data = await _api.post('/wallet/fund', auth: true, body: {
      'amount': amount,
    }) as Map<String, dynamic>;
    return (data['balance'] as num).toDouble();
  }

  Future<double> withdraw(double amount, String pin) async {
    final data = await _api.post('/wallet/withdraw', auth: true, body: {
      'amount': amount,
      'pin': pin,
    }) as Map<String, dynamic>;
    return (data['balance'] as num).toDouble();
  }
}
