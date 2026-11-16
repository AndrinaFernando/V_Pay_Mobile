import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_received_payment.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_received_payments_service.dart';

class _FakeApiClient implements MerchantReceivedPaymentsApiClient {
  _FakeApiClient(this.response);

  final http.Response response;
  String? requestedPath;

  @override
  Future<http.Response> authenticatedGet(String path) async {
    requestedPath = path;
    return response;
  }
}

void main() {
  test(
    'calls the approved authenticated endpoint and sorts newest first',
    () async {
      final client = _FakeApiClient(
        http.Response(
          '{"success":true,"data":{"transactions":['
          '{"transactionId":"older-id","paymentReference":"ref-old","amountMinor":1000,"currency":"LKR","status":"SUCCESS","createdAt":"2026-11-14T08:00:00.000Z"},'
          '{"transactionId":"newer-id","paymentReference":"ref-new","amountMinor":250050,"currency":"LKR","status":"SUCCESS","createdAt":"2026-11-15T08:00:00.000Z"}'
          ']}}',
          200,
        ),
      );
      final service = ApiMerchantReceivedPaymentsService(apiClient: client);

      final payments = await service.getReceivedPayments(limit: 20);

      expect(client.requestedPath, '/api/merchant/transactions?limit=20');
      expect(payments.map((payment) => payment.transactionId), [
        'newer-id',
        'older-id',
      ]);
      expect(payments.first.amountMinor, 250050);
      expect(
        formatMerchantLkrMinor(payments.first.amountMinor),
        'LKR 2,500.50',
      );
      expect(payments.first.createdAt, DateTime.utc(2026, 11, 15, 8));
    },
  );

  test('accepts an empty transaction list', () async {
    final service = ApiMerchantReceivedPaymentsService(
      apiClient: _FakeApiClient(
        http.Response('{"success":true,"data":{"transactions":[]}}', 200),
      ),
    );
    expect(await service.getReceivedPayments(), isEmpty);
  });

  test(
    'rejects a non-success record, wrong currency, or invalid amount',
    () async {
      final records = [
        '{"transactionId":"id","paymentReference":"ref","amountMinor":100,"currency":"LKR","status":"PENDING","createdAt":"2026-11-15T08:00:00.000Z"}',
        '{"transactionId":"id","paymentReference":"ref","amountMinor":100,"currency":"USD","status":"SUCCESS","createdAt":"2026-11-15T08:00:00.000Z"}',
        '{"transactionId":"id","paymentReference":"ref","amountMinor":0,"currency":"LKR","status":"SUCCESS","createdAt":"2026-11-15T08:00:00.000Z"}',
      ];
      for (final record in records) {
        final service = ApiMerchantReceivedPaymentsService(
          apiClient: _FakeApiClient(
            http.Response(
              '{"success":true,"data":{"transactions":[$record]}}',
              200,
            ),
          ),
        );
        await expectLater(
          service.getReceivedPayments(),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test('enforces the backend maximum of 50 records', () async {
    final service = ApiMerchantReceivedPaymentsService(
      apiClient: _FakeApiClient(http.Response('{}', 200)),
    );
    await expectLater(
      service.getReceivedPayments(limit: 0),
      throwsArgumentError,
    );
    await expectLater(
      service.getReceivedPayments(limit: 51),
      throwsArgumentError,
    );
  });

  test(
    'maps authorization errors without exposing an unparsed response',
    () async {
      final service = ApiMerchantReceivedPaymentsService(
        apiClient: _FakeApiClient(
          http.Response('{"success":false,"message":"Denied"}', 403),
        ),
      );
      await expectLater(
        service.getReceivedPayments(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.message, 'message', 'Denied'),
        ),
      );
    },
  );
}
