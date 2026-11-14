import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/merchant/services/payment_intent_service.dart';

class _FakeApiClient implements PaymentIntentApiClient {
  _FakeApiClient(this.response, {this.getResponse});

  final http.Response response;
  final http.Response? getResponse;
  String? path;
  String? getPath;
  Object? body;

  @override
  Future<http.Response> authenticatedPost(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    return response;
  }

  @override
  Future<http.Response> authenticatedGet(String path) async {
    getPath = path;
    return getResponse ?? response;
  }
}

Map<String, Object?> _intentJson({
  int amountMinor = 1235,
  String currency = 'LKR',
  String status = 'PENDING',
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final now = DateTime.now();
  return {
    'paymentReference': 'server-reference-abc123',
    'merchantName': 'Central Canteen',
    'amountMinor': amountMinor,
    'currency': currency,
    'status': status,
    'createdAt': (createdAt ?? now).toIso8601String(),
    'expiresAt': (expiresAt ?? now.add(const Duration(minutes: 15)))
        .toIso8601String(),
    'description': 'Lunch order',
  };
}

void main() {
  test(
    'uses the authenticated contract and validates the intent response',
    () async {
      final apiClient = _FakeApiClient(
        http.Response(
          jsonEncode({
            'success': true,
            'data': {'paymentIntent': _intentJson()},
          }),
          201,
        ),
      );
      final service = ApiPaymentIntentService(apiClient: apiClient);

      final intent = await service.createPaymentIntent(
        amountMinor: 1235,
        description: '  Lunch order  ',
      );

      expect(apiClient.path, '/api/payment-intents');
      expect(apiClient.body, {
        'amountMinor': 1235,
        'currency': 'LKR',
        'description': 'Lunch order',
      });
      expect(intent.paymentReference, 'server-reference-abc123');
      expect(intent.status, 'PENDING');
    },
  );

  test('rejects a response that does not match the submitted amount', () async {
    final service = ApiPaymentIntentService(
      apiClient: _FakeApiClient(
        http.Response(
          jsonEncode({
            'success': true,
            'data': {'paymentIntent': _intentJson(amountMinor: 999)},
          }),
          201,
        ),
      ),
    );

    await expectLater(
      service.createPaymentIntent(amountMinor: 1235),
      throwsA(isA<ApiException>()),
    );
  });

  test('surfaces backend validation errors', () async {
    final service = ApiPaymentIntentService(
      apiClient: _FakeApiClient(
        http.Response(
          jsonEncode({'success': false, 'message': 'Invalid amount'}),
          400,
        ),
      ),
    );

    await expectLater(
      service.createPaymentIntent(amountMinor: 1235),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.message, 'message', 'Invalid amount'),
      ),
    );
  });

  test(
    'maps a legacy COMPLETED response to the agreed SUCCESS status',
    () async {
      final createdAt = DateTime.now().subtract(const Duration(minutes: 1));
      final expiresAt = DateTime.now().add(const Duration(minutes: 14));
      final apiClient = _FakeApiClient(
        http.Response('', 201),
        getResponse: http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'paymentIntent': _intentJson(
                status: 'COMPLETED',
                createdAt: createdAt,
                expiresAt: expiresAt,
              ),
            },
          }),
          200,
        ),
      );
      final service = ApiPaymentIntentService(apiClient: apiClient);

      final intent = await service.getPaymentIntent(
        paymentReference: 'server-reference-abc123',
      );

      expect(apiClient.getPath, '/api/payment-intents/server-reference-abc123');
      expect(intent.status, 'SUCCESS');
    },
  );

  test('accepts every status in the backend payment-intent contract', () async {
    const statuses = ['PENDING', 'PROCESSING', 'SUCCESS', 'FAILED', 'EXPIRED'];

    for (final status in statuses) {
      final apiClient = _FakeApiClient(
        http.Response('', 201),
        getResponse: http.Response(
          jsonEncode({
            'success': true,
            'data': {'paymentIntent': _intentJson(status: status)},
          }),
          200,
        ),
      );
      final service = ApiPaymentIntentService(apiClient: apiClient);

      final intent = await service.getPaymentIntent(
        paymentReference: 'server-reference-abc123',
      );

      expect(intent.status, status);
      expect(apiClient.getPath, '/api/payment-intents/server-reference-abc123');
    }
  });

  test('rejects a status response for a different payment reference', () async {
    final apiClient = _FakeApiClient(
      http.Response('', 201),
      getResponse: http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'paymentIntent': {
              ..._intentJson(),
              'paymentReference': 'another-reference',
            },
          },
        }),
        200,
      ),
    );
    final service = ApiPaymentIntentService(apiClient: apiClient);

    await expectLater(
      service.getPaymentIntent(paymentReference: 'server-reference-abc123'),
      throwsA(isA<ApiException>()),
    );
  });
}
