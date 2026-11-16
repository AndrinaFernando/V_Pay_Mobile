import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/merchant_balance.dart';

abstract interface class MerchantBalanceService {
  Future<MerchantBalance> getMerchantBalance();
}

abstract interface class MerchantBalanceApiClient {
  Future<http.Response> authenticatedGet(String path);
}

class _ApiClientAdapter implements MerchantBalanceApiClient {
  _ApiClientAdapter(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<http.Response> authenticatedGet(String path) =>
      _apiClient.authenticatedGet(path);
}

class ApiMerchantBalanceService implements MerchantBalanceService {
  ApiMerchantBalanceService({MerchantBalanceApiClient? apiClient})
    : _apiClient = apiClient ?? _ApiClientAdapter(ApiClient());

  final MerchantBalanceApiClient _apiClient;

  @override
  Future<MerchantBalance> getMerchantBalance() async {
    final http.Response response;
    try {
      response = await _apiClient
          .authenticatedGet('/api/merchant/balance')
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      rethrow;
    } on SocketException {
      rethrow;
    } on http.ClientException {
      rethrow;
    }

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, response.statusCode),
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final balanceMinor = data['balanceMinor'];
      final currency = data['currency'];
      if (decoded['success'] != true ||
          balanceMinor is! int ||
          balanceMinor < 0 ||
          balanceMinor > 9007199254740991 ||
          currency != 'LKR') {
        throw const FormatException('Invalid merchant balance response');
      }
      return MerchantBalance(balanceMinor: balanceMinor, currency: currency);
    } on FormatException {
      throw const ApiException(
        200,
        'VPay returned an invalid merchant balance.',
      );
    } on TypeError {
      throw const ApiException(
        200,
        'VPay returned an invalid merchant balance.',
      );
    }
  }

  String _responseMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Use the generic status message below for non-JSON server responses.
    }

    return switch (statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'This account cannot view a merchant balance.',
      404 => 'Merchant wallet is not available yet.',
      409 => 'Merchant wallet is currently unavailable.',
      _ => 'Unable to retrieve merchant balance.',
    };
  }
}
