import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _client = http.Client();

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await AuthStorage.instance.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$p');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {bool auth = false, Map<String, String>? query}) async {
    try {
      final res = await _client
          .get(_uri(path, query), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        'Cannot reach API at ${ApiConfig.baseUrl}. Is npm run dev running?',
      );
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      final res = await _client
          .post(
            _uri(path),
            headers: await _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        'Cannot reach API at ${ApiConfig.baseUrl}. Is npm run dev running?',
      );
    }
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      final res = await _client
          .patch(
            _uri(path),
            headers: await _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        'Cannot reach API at ${ApiConfig.baseUrl}. Is npm run dev running?',
      );
    }
  }


  Future<dynamic> put(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      final res = await _client
          .put(
            _uri(path),
            headers: await _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        'Cannot reach API at ${ApiConfig.baseUrl}. Is npm run dev running?',
      );
    }
  }
  dynamic _handle(http.Response res) {
    if (kDebugMode) {
      debugPrint('API ${res.request?.method} ${res.request?.url} → ${res.statusCode}');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = res.body;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final message = data is Map && data['error'] != null
        ? data['error'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, message);
  }
}
