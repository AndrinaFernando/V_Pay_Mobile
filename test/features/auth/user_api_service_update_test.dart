import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vpay_mobile/core/network/api_client.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/services/user_api_service.dart';

class FakeAuth implements AuthService {
  @override
  Future<String?> getFreshIdToken() async => 'test-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const success = '''{
  "success": true, "data": {"user": {
    "uid": "m1", "name": "Amara Perera", "email": "amara@example.test",
    "phone": "+94771112233", "role": "MERCHANT", "status": "ACTIVE",
    "businessName": "ABC Supermarket", "businessCategory": "Retail",
    "businessAddress": "Main Street, Colombo"
  }}
}''';

void main() {
  test(
    'PATCH uses /api/me, Bearer token, JSON, and editable fields only',
    () async {
      final client = ApiClient(
        authService: FakeAuth(),
        httpClient: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/me');
          expect(request.headers['Authorization'], 'Bearer test-id-token');
          expect(
            request.headers['Content-Type'],
            startsWith('application/json'),
          );
          expect(
            request.body,
            '{"name":"Amara Perera","phone":"0771112233","businessName":"ABC Supermarket","businessCategory":"Retail","businessAddress":"Main Street, Colombo"}',
          );
          return http.Response(success, 200);
        }),
      );
      final profile = await UserApiService(apiClient: client)
          .updateCurrentUserProfile(
            name: ' Amara Perera ',
            phone: '0771112233',
            businessName: ' ABC Supermarket ',
            businessCategory: 'Retail',
            businessAddress: ' Main Street, Colombo ',
          );
      expect(profile.businessName, 'ABC Supermarket');
      expect(profile.phone, '+94771112233');
      expect(profile.role, 'MERCHANT');
    },
  );

  test('customer update body excludes merchant and protected fields', () async {
    final client = ApiClient(
      authService: FakeAuth(),
      httpClient: MockClient((request) async {
        expect(request.body, '{"name":"John Silva","phone":"0771112233"}');
        return http.Response(success, 200);
      }),
    );
    await UserApiService(apiClient: client)
        .updateCurrentUserProfile(name: 'John Silva', phone: '0771112233');
  });

  test('API errors and malformed success responses are rejected', () async {
    final apiError = UserApiService(
      apiClient: ApiClient(
        authService: FakeAuth(),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"message":"Enter a valid Sri Lankan mobile number"}',
            400,
          ),
        ),
      ),
    );
    await expectLater(
      apiError.updateCurrentUserProfile(phone: 'bad'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    final malformed = UserApiService(
      apiClient: ApiClient(
        authService: FakeAuth(),
        httpClient: MockClient((_) async => http.Response('not-json', 200)),
      ),
    );
    await expectLater(
      malformed.updateCurrentUserProfile(name: 'John'),
      throwsA(isA<ApiException>()),
    );
  });

  test('network failures propagate without a false success', () async {
    final service = UserApiService(
      apiClient: ApiClient(
        authService: FakeAuth(),
        httpClient: MockClient(
          (_) async => throw const SocketException('offline'),
        ),
      ),
    );
    await expectLater(
      service.updateCurrentUserProfile(name: 'John'),
      throwsA(isA<SocketException>()),
    );
  });
}
