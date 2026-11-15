import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/vpay_card.dart';

class CardApiService {
  CardApiService({ApiClient? apiClient}) : _providedApiClient = apiClient;

  final ApiClient? _providedApiClient;
  late final ApiClient _apiClient = _providedApiClient ?? ApiClient();

  Future<VPayCard> getCurrentUserCard() async {
    final response = await _apiClient
        .authenticatedGet('/api/card')
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Unable to retrieve VPay card');
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final card = data['card'] as Map<String, dynamic>;
      return VPayCard.fromJson(card);
    } on FormatException {
      throw const ApiException(200, 'Invalid card response');
    } on TypeError {
      throw const ApiException(200, 'Invalid card response');
    }
  }
}
