import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_confirmation_service.dart';

class _FakeApiClient implements CustomerPaymentApiClient {
  _FakeApiClient({required this.postResponse, required this.getResponse});

  final Future<http.Response> Function(String path, Object? body) postResponse;
  final Future<http.Response> Function(String path) getResponse;
  final postPaths = <String>[];
  final getPaths = <String>[];
  final postBodies = <Object?>[];

  @override
  Future<http.Response> authenticatedPost(String path, {Object? body}) {
    postPaths.add(path);
    postBodies.add(body);
    return postResponse(path, body);
  }

  @override
  Future<http.Response> authenticatedGet(String path) {
    getPaths.add(path);
    return getResponse(path);
  }
}

Map<String, dynamic> _successEnvelope() {
  return {
    'success': true,
    'data': {
      'payment': {
        'transactionId': 'qr-payment--abc123',
        'paymentReference': 'abc123',
        'merchantName': 'Test Merchant',
        'amountMinor': 12550,
        'currency': 'LKR',
        'status': 'SUCCESS',
        'paidAt': '2026-11-15T10:00:00.000Z',
      },
    },
  };
}

Map<String, dynamic> _statusEnvelope(String status) {
  if (status == 'SUCCESS') return _successEnvelope();
  return {
    'success': true,
    'data': {
      'payment': {'paymentReference': 'abc123', 'status': status},
    },
  };
}

void main() {
  test(
    'confirms using only the encoded reference and no request body',
    () async {
      final apiClient = _FakeApiClient(
        postResponse: (_, _) async =>
            http.Response(jsonEncode(_successEnvelope()), 200),
        getResponse: (_) async => http.Response('{}', 500),
      );
      final service = ApiCustomerPaymentConfirmationService(
        apiClient: apiClient,
      );

      final result = await service.confirmPayment(' abc123 ');

      expect(result.status, CustomerPaymentStatus.success);
      expect(result.transactionId, 'qr-payment--abc123');
      expect(result.amountMinor, 12550);
      expect(apiClient.postPaths, ['/api/payment-intents/abc123/confirm']);
      expect(apiClient.postBodies, [null]);
    },
  );

  test('uses the read-only payment-status contract for recovery', () async {
    final apiClient = _FakeApiClient(
      postResponse: (_, _) async => http.Response('{}', 500),
      getResponse: (_) async =>
          http.Response(jsonEncode(_statusEnvelope('PROCESSING')), 200),
    );
    final service = ApiCustomerPaymentConfirmationService(apiClient: apiClient);

    final result = await service.getPaymentStatus('abc123');

    expect(result.status, CustomerPaymentStatus.processing);
    expect(apiClient.getPaths, ['/api/payment-intents/abc123/payment-status']);
    expect(apiClient.postPaths, isEmpty);
  });

  test('parses the backend successful payment-status contract', () async {
    final apiClient = _FakeApiClient(
      postResponse: (_, _) async => http.Response('{}', 500),
      getResponse: (_) async =>
          http.Response(jsonEncode(_successEnvelope()), 200),
    );
    final service = ApiCustomerPaymentConfirmationService(apiClient: apiClient);

    final result = await service.getPaymentStatus('abc123');

    expect(result.status, CustomerPaymentStatus.success);
    expect(result.transactionId, 'qr-payment--abc123');
    expect(result.paymentReference, 'abc123');
    expect(result.amountMinor, 12550);
    expect(result.currency, 'LKR');
    expect(result.paidAt, DateTime.utc(2026, 11, 15, 10));
    expect(apiClient.getPaths, ['/api/payment-intents/abc123/payment-status']);
    expect(apiClient.postPaths, isEmpty);
  });

  test('maps known backend rejection codes to stable failures', () async {
    const cases = {
      'INSUFFICIENT_BALANCE':
          CustomerPaymentConfirmationFailure.insufficientBalance,
      'MINIMUM_BALANCE_REQUIRED':
          CustomerPaymentConfirmationFailure.minimumBalanceRequired,
      'PAYMENT_LIMIT_EXCEEDED':
          CustomerPaymentConfirmationFailure.limitExceeded,
      'CARD_FROZEN': CustomerPaymentConfirmationFailure.cardFrozen,
      'PAYMENT_ALREADY_PAID': CustomerPaymentConfirmationFailure.alreadyPaid,
      'PAYMENT_UNAVAILABLE': CustomerPaymentConfirmationFailure.unavailable,
    };

    for (final entry in cases.entries) {
      final apiClient = _FakeApiClient(
        postResponse: (_, _) async => http.Response(
          jsonEncode({'success': false, 'code': entry.key}),
          entry.key == 'PAYMENT_UNAVAILABLE' ? 503 : 409,
        ),
        getResponse: (_) async => http.Response('{}', 500),
      );
      final service = ApiCustomerPaymentConfirmationService(
        apiClient: apiClient,
      );

      await expectLater(
        service.confirmPayment('abc123'),
        throwsA(
          isA<CustomerPaymentConfirmationException>().having(
            (error) => error.failure,
            'failure',
            entry.value,
          ),
        ),
      );
    }
  });

  test(
    'classifies confirmation timeout as ambiguous for status recovery',
    () async {
      final neverCompletes = Completer<http.Response>();
      final apiClient = _FakeApiClient(
        postResponse: (_, _) => neverCompletes.future,
        getResponse: (_) async => http.Response('{}', 500),
      );
      final service = ApiCustomerPaymentConfirmationService(
        apiClient: apiClient,
        timeout: Duration.zero,
      );

      await expectLater(
        service.confirmPayment('abc123'),
        throwsA(
          isA<CustomerPaymentConfirmationException>().having(
            (error) => error.failure,
            'failure',
            CustomerPaymentConfirmationFailure.ambiguousNetwork,
          ),
        ),
      );
      expect(apiClient.postPaths, hasLength(1));
      expect(apiClient.getPaths, isEmpty);
    },
  );

  for (final statusCode in [500, 502]) {
    test(
      'classifies unexpected confirmation HTTP $statusCode as ambiguous',
      () async {
        final apiClient = _FakeApiClient(
          postResponse: (_, _) async => http.Response(
            jsonEncode({'success': false, 'code': 'UNEXPECTED_SERVER_FAILURE'}),
            statusCode,
          ),
          getResponse: (_) async => http.Response('{}', 500),
        );
        final service = ApiCustomerPaymentConfirmationService(
          apiClient: apiClient,
        );

        await expectLater(
          service.confirmPayment('abc123'),
          throwsA(
            isA<CustomerPaymentConfirmationException>().having(
              (error) => error.failure,
              'failure',
              CustomerPaymentConfirmationFailure.ambiguousNetwork,
            ),
          ),
        );
        expect(apiClient.postPaths, ['/api/payment-intents/abc123/confirm']);
        expect(apiClient.getPaths, isEmpty);
      },
    );
  }

  test('rejects mismatched and incomplete success receipts', () async {
    final envelope = _successEnvelope();
    final payment =
        (envelope['data'] as Map<String, dynamic>)['payment']
            as Map<String, dynamic>;
    payment['paymentReference'] = 'different-reference';
    final apiClient = _FakeApiClient(
      postResponse: (_, _) async => http.Response(jsonEncode(envelope), 200),
      getResponse: (_) async => http.Response('{}', 500),
    );
    final service = ApiCustomerPaymentConfirmationService(apiClient: apiClient);

    await expectLater(
      service.confirmPayment('abc123'),
      throwsA(
        isA<CustomerPaymentConfirmationException>().having(
          (error) => error.failure,
          'failure',
          CustomerPaymentConfirmationFailure.invalidResponse,
        ),
      ),
    );
  });
}
