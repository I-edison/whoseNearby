import 'api_client.dart';
import 'auth_storage.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;
  final _storage = AuthStorage.instance;

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final data = await _api.post('/auth/login', body: {
      'identifier': identifier.trim(),
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    await _storage.saveSession(token: token, user: user);
    return user;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String identifier,
    required String password,
    String? role,
    String? city,
    String? area,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName.trim(),
      'password': password,
      if (role != null) 'role': role,
      if (city != null) 'city': city,
      if (area != null) 'area': area,
    };

    // Treat as email if it contains @, otherwise phone (digits only)
    final id = _normalizeTarget(identifier);
    if (identifier.contains('@')) {
      body['email'] = id;
    } else {
      body['phone'] = id;
    }

    // Account is created only after OTP verify — do not save session here.
    final data = await _api.post('/auth/register', body: body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Strip spaces; keep email lowercased so OTP target matches register.
  String _normalizeTarget(String raw) {
    final t = raw.trim();
    if (t.contains('@')) return t.toLowerCase();
    return t.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<Map<String, dynamic>> requestOtp(String target) async {
    final data = await _api.post('/auth/otp/request', body: {
      'target': _normalizeTarget(target),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({required String target, required String code}) async {
    final data = await _api.post('/auth/otp/verify', body: {
      'target': _normalizeTarget(target),
      'code': code.trim().replaceAll(RegExp(r'\s'), ''),
    }) as Map<String, dynamic>;
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token != null && user != null) {
      await _storage.saveSession(token: token, user: user);
    }
    return data;
  }

  Future<Map<String, dynamic>?> me() async {
    try {
      final data = await _api.get('/auth/me', auth: true) as Map<String, dynamic>;
      await _storage.saveSession(
        token: (await _storage.getToken())!,
        user: data,
      );
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
  }

  Future<bool> isLoggedIn() => _storage.isLoggedIn();
  Future<Map<String, dynamic>?> currentUser() => _storage.getUser();
}
