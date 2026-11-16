import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_balance_service.dart';

class _FakeApiClient implements MerchantBalanceApiClient {
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
    'uses the authenticated merchant balance endpoint and parses minor units',
    () async {
      final client = _FakeApiClient(
        http.Response(
          '{"success":true,"data":{"balanceMinor":123456,"currency":"LKR"}}',
          200,
        ),
      );
      final service = ApiMerchantBalanceService(apiClient: client);

      final balance = await service.getMerchantBalance();

      expect(client.requestedPath, '/api/merchant/balance');
      expect(balance.balanceMinor, 123456);
      expect(balance.currency, 'LKR');
      expect(balance.formattedLkr, 'LKR 1,234.56');
    },
  );

  test('accepts a genuine zero balance', () async {
    final service = ApiMerchantBalanceService(
      apiClient: _FakeApiClient(
        http.Response(
          '{"success":true,"data":{"balanceMinor":0,"currency":"LKR"}}',
          200,
        ),
      ),
    );

    expect((await service.getMerchantBalance()).formattedLkr, 'LKR 0.00');
  });

  test('maps authorization failures to API exceptions', () async {
    final service = ApiMerchantBalanceService(
      apiClient: _FakeApiClient(
        http.Response('{"success":false,"message":"Denied"}', 403),
      ),
    );

    expect(
      () => service.getMerchantBalance(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.message, 'message', 'Denied'),
      ),
    );
  });

  test('rejects malformed balance data and non-LKR currencies', () async {
    for (final data in [
      '{"balanceMinor":-1,"currency":"LKR"}',
      '{"balanceMinor":12.5,"currency":"LKR"}',
      '{"balanceMinor":12,"currency":"USD"}',
    ]) {
      final service = ApiMerchantBalanceService(
        apiClient: _FakeApiClient(
          http.Response('{"success":true,"data":$data}', 200),
        ),
      );
      await expectLater(
        service.getMerchantBalance(),
        throwsA(isA<ApiException>()),
      );
    }
  });
}
