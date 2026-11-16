import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/merchant_received_payment.dart';

abstract interface class MerchantReceivedPaymentsService {
  Future<List<MerchantReceivedPayment>> getReceivedPayments({int limit = 20});
}

abstract interface class MerchantReceivedPaymentsApiClient {
  Future<http.Response> authenticatedGet(String path);
}

class _ApiClientAdapter implements MerchantReceivedPaymentsApiClient {
  _ApiClientAdapter(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<http.Response> authenticatedGet(String path) =>
      _apiClient.authenticatedGet(path);
}

class ApiMerchantReceivedPaymentsService
    implements MerchantReceivedPaymentsService {
  ApiMerchantReceivedPaymentsService({
    MerchantReceivedPaymentsApiClient? apiClient,
    this.timeout = const Duration(seconds: 15),
  }) : _apiClient = apiClient ?? _ApiClientAdapter(ApiClient());

  final MerchantReceivedPaymentsApiClient _apiClient;
  final Duration timeout;

  @override
  Future<List<MerchantReceivedPayment>> getReceivedPayments({
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'must be from 1 to 50');
    }

    final http.Response response;
    try {
      response = await _apiClient
          .authenticatedGet('/api/merchant/transactions?limit=$limit')
          .timeout(timeout);
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
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) throw const FormatException();
      final data = body['data'] as Map<String, dynamic>;
      final rawTransactions = data['transactions'] as List<dynamic>;
      final transactions = rawTransactions
          .map(
            (item) =>
                MerchantReceivedPayment.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      transactions.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      return transactions;
    } on FormatException {
      throw const ApiException(
        200,
        'Invalid merchant transaction history response.',
      );
    } on TypeError {
      throw const ApiException(
        200,
        'Invalid merchant transaction history response.',
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
      // Use the status-specific fallback for non-JSON responses.
    }

    return switch (statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'This account cannot access merchant payment history.',
      400 => 'The payment history request is invalid.',
      _ => 'Unable to retrieve received payments.',
    };
  }
}
