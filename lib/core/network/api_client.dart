import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/auth_service.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<http.Response> authenticatedGet(String path) async {
    final token = await _getToken();

    return http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  Future<http.Response> authenticatedPost(String path, {Object? body}) async {
    final token = await _getToken();

    return http.post(
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
