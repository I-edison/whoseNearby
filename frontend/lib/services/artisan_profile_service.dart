import 'api_client.dart';

class ArtisanProfileService {
  ArtisanProfileService._();
  static final ArtisanProfileService instance = ArtisanProfileService._();
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>?> getMine() async {
    try {
      return await _api.get('/artisans/profile', auth: true) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> save({
    required String businessName,
    required String primarySkill,
    String? bio,
    double? hourlyRate,
  }) async {
    return await _api.post('/artisans/profile', auth: true, body: {
      'businessName': businessName,
      'primarySkill': primarySkill,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
    }) as Map<String, dynamic>;
  }

  Future<void> setAvailability(bool isAvailable) async {
    await _api.patch('/artisans/profile/availability', auth: true, body: {
      'isAvailable': isAvailable,
    });
  }
}
