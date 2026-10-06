import 'api_client.dart';

class ArtisanService {
  ArtisanService._();
  static final ArtisanService instance = ArtisanService._();
  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list({
    String? skill,
    String? q,
    double? lat,
    double? lng,
    double radius = 10,
    bool availableOnly = false,
  }) async {
    final query = <String, String>{
      if (skill != null && skill.isNotEmpty) 'skill': skill,
      if (q != null && q.isNotEmpty) 'q': q,
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
      'radius': radius.toString(),
      if (availableOnly) 'available': 'true',
    };
    final data = await _api.get('/artisans', query: query) as Map<String, dynamic>;
    final list = data['artisans'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return await _api.get('/artisans/$id') as Map<String, dynamic>;
  }
}
