import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_client.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_preview_service.dart';

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.response) : super(authService: _FakeAuthService());

  final Future<http.Response> Function(String path) response;
  final paths = <String>[];

  @override
  Future<http.Response> authenticatedGet(String path) {
    paths.add(path);
    return response(path);
  }
}

Map<String, dynamic> _validEnvelope() {
  return {
    'success': true,
    'data': {
      'paymentIntent': {
        'paymentReference': 'abc123',
        'merchantName': 'Test Merchant',
        'amountMinor': 125000,
        'currency': 'LKR',
        'status': 'PENDING',
        'createdAt': '2026-11-14T15:30:00.000Z',
        'expiresAt': '2026-11-14T15:45:00.000Z',
        'description': 'Order 123',
      },
    },
  };
}

void main() {
  test(
    'uses the authenticated customer preview endpoint and parses data',
    () async {
      final apiClient = _FakeApiClient(
        (_) async => http.Response(jsonEncode(_validEnvelope()), 200),
      );
      final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);

      final preview = await service.getPreview(' abc123 ');

      expect(preview.paymentReference, 'abc123');
      expect(preview.merchantName, 'Test Merchant');
      expect(preview.amountMinor, 125000);
      expect(preview.description, 'Order 123');
      expect(apiClient.paths, ['/api/payment-intents/abc123/preview']);
    },
  );

  test('rejects a payment reference that does not match the scan', () async {
    final apiClient = _FakeApiClient(
      (_) async => http.Response(jsonEncode(_validEnvelope()), 200),
    );
    final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);

    expect(
      () => service.getPreview('different-reference'),
      throwsA(
        isA<CustomerPaymentPreviewException>().having(
          (error) => error.failure,
          'failure',
          CustomerPaymentPreviewFailure.invalidResponse,
        ),
      ),
    );
  });

  test('trims and encodes the scanned reference', () async {
    final envelope = _validEnvelope();
    ((envelope['data'] as Map<String, dynamic>)['paymentIntent']
            as Map<String, dynamic>)['paymentReference'] =
        'ref/with space';
    final apiClient = _FakeApiClient(
      (_) async => http.Response(jsonEncode(envelope), 200),
    );
    final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);

    await service.getPreview(' ref/with space ');

    expect(apiClient.paths, [
      '/api/payment-intents/ref%2Fwith%20space/preview',
    ]);
  });

  test('rejects missing references and non-positive payment amounts', () async {
    Future<CustomerPaymentPreviewFailure> failureFor(
      Map<String, dynamic> envelope,
    ) async {
      final apiClient = _FakeApiClient(
        (_) async => http.Response(jsonEncode(envelope), 200),
      );
      final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);
      try {
        await service.getPreview('abc123');
        fail('Expected preview lookup to fail');
      } on CustomerPaymentPreviewException catch (error) {
        return error.failure;
      }
    }

    final missingReference = _validEnvelope();
    ((missingReference['data'] as Map<String, dynamic>)['paymentIntent']
            as Map<String, dynamic>)
        .remove('paymentReference');
    expect(
      await failureFor(missingReference),
      CustomerPaymentPreviewFailure.invalidResponse,
    );

    final emptyReference = _validEnvelope();
    ((emptyReference['data'] as Map<String, dynamic>)['paymentIntent']
            as Map<String, dynamic>)['paymentReference'] =
        '   ';
    expect(
      await failureFor(emptyReference),
      CustomerPaymentPreviewFailure.invalidResponse,
    );

    for (final amount in [0, -1, 1.5]) {
      final invalidAmount = _validEnvelope();
      ((invalidAmount['data'] as Map<String, dynamic>)['paymentIntent']
              as Map<String, dynamic>)['amountMinor'] =
          amount;
      expect(
        await failureFor(invalidAmount),
        CustomerPaymentPreviewFailure.invalidResponse,
      );
    }
  });

  test(
    'distinguishes authentication from account eligibility responses',
    () async {
      Future<CustomerPaymentPreviewException> errorFor(
        http.Response response,
      ) async {
        final apiClient = _FakeApiClient((_) async => response);
        final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);
        try {
          await service.getPreview('payment-ref');
          fail('Expected preview lookup to fail');
        } on CustomerPaymentPreviewException catch (error) {
          return error;
        }
      }

      expect(
        (await errorFor(http.Response('{}', 401))).failure,
        CustomerPaymentPreviewFailure.authentication,
      );
      expect(
        (await errorFor(
          http.Response(
            jsonEncode({
              'success': false,
              'message': 'Email verification is required',
            }),
            403,
          ),
        )).failure,
        CustomerPaymentPreviewFailure.accountNotReady,
      );
      expect(
        (await errorFor(
          http.Response(
            jsonEncode({
              'success': false,
              'message':
                  'Only active customer accounts can preview payment intents',
            }),
            403,
          ),
        )).failure,
        CustomerPaymentPreviewFailure.accountNotReady,
      );
    },
  );

  test('maps unknown-reference and invalid responses', () async {
    Future<CustomerPaymentPreviewException> errorFor(
      http.Response response,
    ) async {
      final apiClient = _FakeApiClient((_) async => response);
      final service = ApiCustomerPaymentPreviewService(apiClient: apiClient);
      try {
        await service.getPreview('payment-ref');
        fail('Expected preview lookup to fail');
      } on CustomerPaymentPreviewException catch (error) {
        return error;
      }
    }

    expect(
      (await errorFor(http.Response('{}', 404))).failure,
      CustomerPaymentPreviewFailure.unknownReference,
    );
    expect(
      (await errorFor(http.Response('{"success":true}', 200))).failure,
      CustomerPaymentPreviewFailure.invalidResponse,
    );
  });
}
