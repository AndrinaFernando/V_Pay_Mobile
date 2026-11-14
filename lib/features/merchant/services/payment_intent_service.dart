import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/merchant_payment_intent.dart';

abstract interface class PaymentIntentService {
  Future<MerchantPaymentIntent> createPaymentIntent({
    required int amountMinor,
    String? description,
  });

  Future<MerchantPaymentIntent> getPaymentIntent({
    required String paymentReference,
  });
}

abstract interface class PaymentIntentApiClient {
  Future<http.Response> authenticatedPost(String path, {Object? body});

  Future<http.Response> authenticatedGet(String path);
}

class _ApiClientAdapter implements PaymentIntentApiClient {
  _ApiClientAdapter(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<http.Response> authenticatedPost(String path, {Object? body}) {
    return _apiClient.authenticatedPost(path, body: body);
  }

  @override
  Future<http.Response> authenticatedGet(String path) {
    return _apiClient.authenticatedGet(path);
  }
}

class ApiPaymentIntentService implements PaymentIntentService {
  ApiPaymentIntentService({PaymentIntentApiClient? apiClient})
    : _apiClient = apiClient ?? _ApiClientAdapter(ApiClient());

  final PaymentIntentApiClient _apiClient;

  @override
  Future<MerchantPaymentIntent> createPaymentIntent({
    required int amountMinor,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'amountMinor': amountMinor,
      'currency': 'LKR',
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };

    final http.Response response;
    try {
      response = await _apiClient
          .authenticatedPost('/api/payment-intents', body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      rethrow;
    } on SocketException {
      rethrow;
    } on http.ClientException {
      rethrow;
    }

    if (response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, response.statusCode),
      );
    }

    final intent = _parseIntentResponse(response.body);
    if (intent.amountMinor != amountMinor || intent.status != 'PENDING') {
      throw const ApiException(
        200,
        'The server returned an invalid payment request.',
      );
    }
    return intent;
  }

  @override
  Future<MerchantPaymentIntent> getPaymentIntent({
    required String paymentReference,
  }) async {
    final http.Response response;
    try {
      response = await _apiClient
          .authenticatedGet(
            '/api/payment-intents/${Uri.encodeComponent(paymentReference)}',
          )
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

    final intent = _parseIntentResponse(response.body);
    const allowedStatuses = {
      'PENDING',
      'PROCESSING',
      'SUCCESS',
      'FAILED',
      'EXPIRED',
    };
    if (intent.paymentReference != paymentReference ||
        intent.currency != 'LKR' ||
        !allowedStatuses.contains(intent.status)) {
      throw const ApiException(
        200,
        'The server returned an invalid payment status.',
      );
    }
    return intent;
  }

  MerchantPaymentIntent _parseIntentResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final intentJson = data['paymentIntent'] as Map<String, dynamic>;
      final intent = MerchantPaymentIntent.fromJson(intentJson);
      if (decoded['success'] != true || intent.currency != 'LKR') {
        throw const FormatException('Invalid payment intent envelope');
      }
      return intent;
    } on FormatException {
      throw const ApiException(
        200,
        'The server returned an invalid payment request.',
      );
    } on TypeError {
      throw const ApiException(
        200,
        'The server returned an invalid payment request.',
      );
    }
  }

  String _responseMessage(String responseBody, int statusCode) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Use a stable fallback if the server did not return JSON.
    }

    return switch (statusCode) {
      400 => 'Check the amount and try again.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'This account cannot create merchant payment requests.',
      _ => 'Unable to create the payment request. Please try again.',
    };
  }
}
