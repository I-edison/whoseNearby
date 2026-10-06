import 'api_client.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();
  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> conversations() async {
    final data = await _api.get('/chat/conversations', auth: true)
        as Map<String, dynamic>;
    final list = data['conversations'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> messages(String jobId) async {
    final data = await _api.get('/chat/$jobId/messages', auth: true)
        as Map<String, dynamic>;
    final list = data['messages'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> send(
    String jobId, {
    required String body,
    double? offerAmount,
  }) async {
    return await _api.post('/chat/$jobId/messages', auth: true, body: {
      'body': body,
      if (offerAmount != null) 'offerAmount': offerAmount,
    }) as Map<String, dynamic>;
  }
}
