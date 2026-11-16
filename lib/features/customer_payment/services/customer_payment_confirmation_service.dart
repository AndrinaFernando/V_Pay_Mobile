import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../models/customer_payment_preview.dart';
import '../models/customer_payment_result.dart';

enum CustomerPaymentConfirmationFailure {
  authentication,
  notFound,
  expired,
  failed,
  alreadyPaid,
  belowMinimum,
  limitExceeded,
  insufficientBalance,
  minimumBalanceRequired,
  cardFrozen,
  cardExpired,
  accountNotReady,
  merchantUnavailable,
  balanceSchema,
  conflict,
  unavailable,
  ambiguousNetwork,
  invalidResponse,
}

class CustomerPaymentConfirmationException implements Exception {
  const CustomerPaymentConfirmationException(this.failure);

  final CustomerPaymentConfirmationFailure failure;
}

abstract interface class CustomerPaymentConfirmationService {
  Future<CustomerPaymentResult> confirmPayment(String paymentReference);

  Future<CustomerPaymentResult> getPaymentStatus(String paymentReference);
}

abstract interface class CustomerPaymentApiClient {
  Future<http.Response> authenticatedPost(String path, {Object? body});

  Future<http.Response> authenticatedGet(String path);
}

class _ApiClientAdapter implements CustomerPaymentApiClient {
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

class ApiCustomerPaymentConfirmationService
    implements CustomerPaymentConfirmationService {
  ApiCustomerPaymentConfirmationService({
    CustomerPaymentApiClient? apiClient,
    this.timeout = const Duration(seconds: 15),
  }) : _apiClient = apiClient ?? _ApiClientAdapter(ApiClient());

  final CustomerPaymentApiClient _apiClient;
  final Duration timeout;

  @override
  Future<CustomerPaymentResult> confirmPayment(String paymentReference) async {
    final reference = _validatedReference(paymentReference);
    final response = await _performRequest(
      () => _apiClient.authenticatedPost(
        '/api/payment-intents/${Uri.encodeComponent(reference)}/confirm',
      ),
    );
    if (response.statusCode != 200) {
      throw CustomerPaymentConfirmationException(
        _failureForResponse(
          response.statusCode,
          response.body,
          unexpectedServerFailureIsAmbiguous: true,
        ),
      );
    }

    final result = _parsePayment(response.body, reference);
    if (result.status != CustomerPaymentStatus.success) {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.invalidResponse,
      );
    }
    return result;
  }

  @override
  Future<CustomerPaymentResult> getPaymentStatus(
    String paymentReference,
  ) async {
    final reference = _validatedReference(paymentReference);
    final response = await _performRequest(
      () => _apiClient.authenticatedGet(
        '/api/payment-intents/${Uri.encodeComponent(reference)}/payment-status',
      ),
    );
    if (response.statusCode != 200) {
      throw CustomerPaymentConfirmationException(
        _failureForResponse(response.statusCode, response.body),
      );
    }
    return _parsePayment(response.body, reference);
  }

  Future<http.Response> _performRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.ambiguousNetwork,
      );
    } on SocketException {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.ambiguousNetwork,
      );
    } on http.ClientException {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.ambiguousNetwork,
      );
    } on StateError {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.authentication,
      );
    }
  }

  String _validatedReference(String paymentReference) {
    final reference = paymentReference.trim();
    if (reference.isEmpty) {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.notFound,
      );
    }
    return reference;
  }

  CustomerPaymentResult _parsePayment(String body, String reference) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['success'] != true) throw const FormatException();
      final data = decoded['data'] as Map<String, dynamic>;
      final paymentJson = data['payment'] as Map<String, dynamic>;
      final payment = CustomerPaymentResult.fromJson(paymentJson);
      if (payment.paymentReference != reference) {
        throw const FormatException('Mismatched payment reference');
      }
      return payment;
    } on FormatException {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.invalidResponse,
      );
    } on TypeError {
      throw const CustomerPaymentConfirmationException(
        CustomerPaymentConfirmationFailure.invalidResponse,
      );
    }
  }

  CustomerPaymentConfirmationFailure _failureForResponse(
    int status,
    String body, {
    bool unexpectedServerFailureIsAmbiguous = false,
  }) {
    final code = _responseCode(body);
    final mapped = switch (code) {
      'PAYMENT_NOT_FOUND' => CustomerPaymentConfirmationFailure.notFound,
      'PAYMENT_EXPIRED' => CustomerPaymentConfirmationFailure.expired,
      'PAYMENT_FAILED' => CustomerPaymentConfirmationFailure.failed,
      'PAYMENT_ALREADY_PAID' => CustomerPaymentConfirmationFailure.alreadyPaid,
      'PAYMENT_BELOW_MINIMUM' =>
        CustomerPaymentConfirmationFailure.belowMinimum,
      'PAYMENT_LIMIT_EXCEEDED' =>
        CustomerPaymentConfirmationFailure.limitExceeded,
      'INSUFFICIENT_BALANCE' =>
        CustomerPaymentConfirmationFailure.insufficientBalance,
      'MINIMUM_BALANCE_REQUIRED' =>
        CustomerPaymentConfirmationFailure.minimumBalanceRequired,
      'CARD_FROZEN' => CustomerPaymentConfirmationFailure.cardFrozen,
      'CARD_EXPIRED' => CustomerPaymentConfirmationFailure.cardExpired,
      'ACCOUNT_NOT_READY' => CustomerPaymentConfirmationFailure.accountNotReady,
      'MERCHANT_UNAVAILABLE' =>
        CustomerPaymentConfirmationFailure.merchantUnavailable,
      'INVALID_BALANCE_SCHEMA' =>
        CustomerPaymentConfirmationFailure.balanceSchema,
      'PAYMENT_CONFLICT' => CustomerPaymentConfirmationFailure.conflict,
      'PAYMENT_UNAVAILABLE' => CustomerPaymentConfirmationFailure.unavailable,
      _ => null,
    };
    if (mapped != null) return mapped;
    if (unexpectedServerFailureIsAmbiguous && status >= 500) {
      return CustomerPaymentConfirmationFailure.ambiguousNetwork;
    }
    if (status == 401 || status == 403) {
      return CustomerPaymentConfirmationFailure.authentication;
    }
    if (status == 404) return CustomerPaymentConfirmationFailure.notFound;
    if (status == 410) return CustomerPaymentConfirmationFailure.expired;
    return CustomerPaymentConfirmationFailure.unavailable;
  }

  String? _responseCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } on FormatException {
      // The HTTP status still provides a safe fallback classification.
    }
    return null;
  }
}
