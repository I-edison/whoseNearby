import 'api_client.dart';

class JobService {
  JobService._();
  static final JobService instance = JobService._();
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> create({
    required String title,
    required String category,
    String? description,
    double? budgetMin,
    double? budgetMax,
    String? city,
    String? area,
    String? whenNeeded,
    String? artisanId,
  }) async {
    return await _api.post('/jobs', auth: true, body: {
      'title': title,
      'category': category,
      if (description != null) 'description': description,
      if (budgetMin != null) 'budgetMin': budgetMin,
      if (budgetMax != null) 'budgetMax': budgetMax,
      if (city != null) 'city': city,
      if (area != null) 'area': area,
      if (whenNeeded != null) 'whenNeeded': whenNeeded,
      if (artisanId != null) 'artisanId': artisanId,
    }) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> mine({String as = 'client'}) async {
    final data = await _api.get('/jobs/mine', auth: true, query: {'as': as})
        as Map<String, dynamic>;
    final list = data['jobs'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return await _api.get('/jobs/$id', auth: true) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assign(String jobId) async {
    return await _api.post('/jobs/$jobId/assign', auth: true)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> start({
    required String jobId,
    required double amount,
    required String pin,
  }) async {
    return await _api.post('/jobs/$jobId/start', auth: true, body: {
      'amount': amount,
      'pin': pin,
    }) as Map<String, dynamic>;
  }

  Future<void> complete({required String jobId, required String code}) async {
    await _api.post('/jobs/$jobId/complete', auth: true, body: {'code': code});
  }

  Future<void> rate({
    required String jobId,
    required int stars,
    String? comment,
  }) async {
    await _api.post('/jobs/$jobId/rate', auth: true, body: {
      'stars': stars,
      if (comment != null) 'comment': comment,
    });
  }
}
