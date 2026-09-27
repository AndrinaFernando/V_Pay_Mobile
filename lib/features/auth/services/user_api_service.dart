import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/user_profile_result.dart';
import '../models/vpay_user_profile.dart';

class UserApiService {
  UserApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<UserProfileResult> getCurrentUserProfile() async {
    final response = await _apiClient.authenticatedGet('/api/me');

    if (response.statusCode == 404) {
      return const UserProfileResult.missing();
    }

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _errorMessage(response.body, response.statusCode),
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      return UserProfileResult.found(VPayUserProfile.fromJson(user));
    } on FormatException {
      throw const ApiException(200, 'Invalid user profile response');
    } on TypeError {
      throw const ApiException(200, 'Invalid user profile response');
    }
  }

  String _errorMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body);

      if (json is Map<String, dynamic> && json['message'] is String) {
        return json['message'] as String;
      }
    } on FormatException {
      // Use a status-specific message when the backend did not return JSON.
    }

    return switch (statusCode) {
      401 => 'Authentication is required',
      403 => 'Email verification is required',
      _ => 'Failed to retrieve user profile',
    };
  }
}
