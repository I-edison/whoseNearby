/// Base URL for WhoseNearby API.
///
/// Multi-phone testing (same Wi-Fi):
/// 1. API on PC: npm run dev (listens on 0.0.0.0:4000)
/// 2. ipconfig → IPv4 e.g. 192.168.1.15
/// 3. Set defaultValue below to http://192.168.1.15:4000
/// 4. flutter run on each phone
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // For phones on Wi-Fi, use your PC IP:
    // defaultValue: 'http://192.168.1.15:4000',
    defaultValue: 'http://localhost:4000',
  );
}
