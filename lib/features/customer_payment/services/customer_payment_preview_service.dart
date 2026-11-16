import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../models/customer_payment_preview.dart';

enum CustomerPaymentPreviewFailure {
  unknownReference,
  customerProfileNotFound,
  expired,
  alreadyUsed,
  authentication,
  accountNotReady,
  network,
  timeout,
  invalidResponse,
  unavailable,
}

class CustomerPaymentPreviewException implements Exception {
  const CustomerPaymentPreviewException(this.failure);

  final CustomerPaymentPreviewFailure failure;
}

abstract interface class CustomerPaymentPreviewService {
  Future<CustomerPaymentPreview> getPreview(String paymentReference);
}

class ApiCustomerPaymentPreviewService
    implements CustomerPaymentPreviewService {
  ApiCustomerPaymentPreviewService({
    ApiClient? apiClient,
    this.timeout = const Duration(seconds: 15),
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final Duration timeout;

  @override
  Future<CustomerPaymentPreview> getPreview(String paymentReference) async {
    final reference = paymentReference.trim();
    if (reference.isEmpty) {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.unknownReference,
      );
    }

    late final http.Response response;
    try {
      response = await _apiClient
          .authenticatedGet(
            '/api/payment-intents/${Uri.encodeComponent(reference)}/preview',
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.timeout,
      );
    } on StateError {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.authentication,
      );
    } on SocketException {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.network,
      );
    } on http.ClientException {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.network,
      );
    }

    if (response.statusCode != 200) {
      throw CustomerPaymentPreviewException(
        _failureForResponse(response.statusCode, response.body),
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) throw const FormatException();
      final data = body['data'] as Map<String, dynamic>;
      final paymentIntent = data['paymentIntent'] as Map<String, dynamic>;
      final preview = CustomerPaymentPreview.fromJson(paymentIntent);
      if (preview.paymentReference != reference) {
        throw const FormatException('Mismatched payment reference');
      }
      return preview;
    } on FormatException {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.invalidResponse,
      );
    } on TypeError {
      throw const CustomerPaymentPreviewException(
        CustomerPaymentPreviewFailure.invalidResponse,
      );
    }
  }

  CustomerPaymentPreviewFailure _failureForResponse(int status, String body) {
    final responseBody = _responseBody(body);
    final message = switch (responseBody['message']) {
      final String value => value.toLowerCase(),
      _ => '',
    };
    final code = switch (responseBody['code']) {
      final String value => value,
      _ => '',
    };

    if (status == 401) {
      return CustomerPaymentPreviewFailure.authentication;
    }
    if (status == 403) {
      return CustomerPaymentPreviewFailure.accountNotReady;
    }
    if (status == 404) {
      if (code == 'CUSTOMER_PROFILE_NOT_FOUND') {
        return CustomerPaymentPreviewFailure.customerProfileNotFound;
      }
      return CustomerPaymentPreviewFailure.unknownReference;
    }
    if (status == 408 || status == 504) {
      return CustomerPaymentPreviewFailure.timeout;
    }
    if (status == 410 || message.contains('expired')) {
      return CustomerPaymentPreviewFailure.expired;
    }
    if (status == 409 ||
        message.contains('already paid') ||
        message.contains('already used') ||
        message.contains('processing')) {
      return CustomerPaymentPreviewFailure.alreadyUsed;
    }
    return CustomerPaymentPreviewFailure.unavailable;
  }

  Map<String, dynamic> _responseBody(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      // The status code still provides a safe generic error classification.
    }
    return const {};
  }
}
