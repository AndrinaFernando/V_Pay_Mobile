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
        'merchantUid': 'merchant-123',
        'merchantName': 'Colombo Cafe',
        'amountMinor': 250050,
        'currency': 'LKR',
        'status': 'PENDING',
        'createdAt': '2099-02-03T08:00:00Z',
        'expiresAt': '2099-02-03T08:15:00Z',
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

      final preview = await service.getPreview(' ref/with space ');

      expect(preview.merchantName, 'Colombo Cafe');
      expect(preview.amountMinor, 250050);
      expect(apiClient.paths, [
        '/api/payment-intents/ref%2Fwith%20space/preview',
      ]);
    },
  );

  test(
    'maps authentication, unknown-reference and invalid responses',
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
        (await errorFor(http.Response('{}', 404))).failure,
        CustomerPaymentPreviewFailure.unknownReference,
      );
      expect(
        (await errorFor(http.Response('{"success":true}', 200))).failure,
        CustomerPaymentPreviewFailure.invalidResponse,
      );
    },
  );
}
