import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'auth_storage.dart';

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final _picker = ImagePicker();
  final _storage = AuthStorage.instance;

  /// Absolute URL for a path returned by the API (`/uploads/...`).
  static String resolveUrl(String? path) {
    if (path == null) return '';
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final p = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$p';
  }

  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('pickImage error: $e');
      return null;
    }
  }

  Future<String> _fileToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType ??
        (name.endsWith('.png') || path.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp') || path.endsWith('.webp')
                ? 'image/webp'
                : name.endsWith('.gif') || path.endsWith('.gif')
                    ? 'image/gif'
                    : 'image/jpeg');
    return 'data:$mime;base64,$b64';
  }

  Future<Map<String, dynamic>> uploadAvatar(XFile file) async {
    final imageBase64 = await _fileToBase64(file);
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/avatar');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'imageBase64': imageBase64}),
        )
        .timeout(const Duration(seconds: 60));
    return _handle(res);
  }

  Future<void> removeAvatar() async {
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/avatar');
    final res = await http
        .delete(
          uri,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    _handle(res);
  }

  Future<List<String>> uploadPortfolio(XFile file) async {
    final imageBase64 = await _fileToBase64(file);
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/portfolio');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'imageBase64': imageBase64}),
        )
        .timeout(const Duration(seconds: 60));
    final data = _handle(res);
    final list = data['portfolio'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<String>> removePortfolioAt(int index) async {
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/portfolio/$index');
    final res = await http
        .delete(
          uri,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    final data = _handle(res);
    final list = data['portfolio'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }


  Future<Map<String, dynamic>> uploadCover(XFile file) async {
    final imageBase64 = await _fileToBase64(file);
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/cover');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'imageBase64': imageBase64}),
        )
        .timeout(const Duration(seconds: 60));
    return _handle(res);
  }

  Future<void> removeCover() async {
    final token = await _storage.getToken();
    final uri = Uri.parse('${_base()}/media/cover');
    final res = await http
        .delete(
          uri,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    _handle(res);
  }

  String _base() {
    const base = ApiConfig.baseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Map<String, dynamic> _handle(http.Response res) {
    dynamic data;
    try {
      data = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      data = {'error': res.body};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(data as Map);
    }
    final msg = data is Map && data['error'] != null
        ? data['error'].toString()
        : 'Upload failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg);
  }
}
