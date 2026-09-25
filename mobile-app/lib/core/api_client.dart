import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Thin HTTP wrapper over the backend REST API.
///
/// - Attaches `Authorization: Bearer <token>` when [tokenProvider] yields one.
/// - Encodes bodies as JSON, decodes the backend `{success, message, data}`
///   envelope, throws [ApiException] on non-2xx or network failure.
/// - Does NOT retry auth failures; providers map 401 -> logout.
class ApiClient {
  final http.Client _http;
  final Future<String?> Function() _tokenProvider;

  ApiClient({http.Client? httpClient, required Future<String?> Function() tokenProvider})
      : _http = httpClient ?? http.Client(),
        // ignore: prefer_initializing_formals (param name differs from private field)
        _tokenProvider = tokenProvider;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
    return _send('GET', uri, null);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return _send('POST', Uri.parse('${ApiConfig.baseUrl}$path'), body);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    return _send('PUT', Uri.parse('${ApiConfig.baseUrl}$path'), body);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', Uri.parse('${ApiConfig.baseUrl}$path'), null);
  }

  Future<Map<String, dynamic>> _send(String method, Uri uri, Map<String, dynamic>? body) async {
    final token = await _tokenProvider();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final streamed = await _http.send(request).timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response.statusCode, response.body);
    } on TimeoutException {
      throw const ApiException(-1, 'Request timed out.');
    } on SocketException {
      throw const ApiException(-1, 'Network unreachable.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(-1, 'Network error: $e');
    }
  }

  Map<String, dynamic> _decode(int status, String body) {
    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Non-JSON body: fall through to generic message below.
    }
    if (status >= 200 && status < 300) return json;
    final message = (json['message'] is String && (json['message'] as String).isNotEmpty)
        ? json['message'] as String
        : 'Request failed ($status).';
    throw ApiException(status, message);
  }

  void close() => _http.close();
}
