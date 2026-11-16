import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/auth_service.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({AuthService? authService, http.Client? httpClient})
    : _authService = authService ?? AuthService(),
      _httpClient = httpClient ?? http.Client();

  final AuthService _authService;
  final http.Client _httpClient;

  Future<http.Response> authenticatedGet(String path) async {
    final token = await _getToken();

    return _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  Future<http.Response> authenticatedPost(String path, {Object? body}) async {
    final token = await _getToken();

    return _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> authenticatedPatch(String path, {Object? body}) async {
    final token = await _getToken();

    return _httpClient.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<String> _getToken() async {
    final token = await _authService.getFreshIdToken();

    if (token == null) {
      throw StateError('No authenticated Firebase user');
    }

    return token;
  }
}
