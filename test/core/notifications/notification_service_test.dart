import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_client.dart';
import 'package:vpay_mobile/core/notifications/notification_service.dart';
import 'package:vpay_mobile/core/notifications/notification_binding.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';

class FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClient extends ApiClient {
  FakeClient(
    this.status, {
    this.body = '{"success":true,"data":{"bindingId":"12345678-1234-4123-8123-123456789abc"}}',
  }) : super(authService: FakeAuth());
  final int status;
  final String body;
  Object? requestBody;
  @override
  Future<http.Response> authenticatedPost(String path, {Object? body}) async {
    expect(path, '/api/notifications/token');
    requestBody = body;
    return http.Response(this.body, status);
  }
}

void main() {
  test('binding rejects stale account and stale registration', () {
    NotificationBinding.set('customer', 'token', 'binding-1');
    expect(NotificationBinding.matches('customer', 'binding-1'), isTrue);
    expect(NotificationBinding.matches('merchant', 'binding-1'), isFalse);
    expect(NotificationBinding.matches('customer', 'binding-2'), isFalse);
    NotificationBinding.clear();
    expect(NotificationBinding.matches('customer', 'binding-1'), isFalse);
  });
  test(
    'foreground service ignores another binding even with a known type',
    () async {
      NotificationBinding.set('customer', 'token', 'current');
      final messages = StreamController<Object?>();
      final received = <NotificationType>[];
      final service = NotificationService(
        requestPermission: () async => true,
        getToken: () async => 'token',
        tokenChanges: const Stream.empty(),
        foregroundMessages: messages.stream,
        openedMessages: const Stream.empty(),
        initialMessage: () async => null,
        isCurrentSession: () => true,
        registerToken: (_) async => RegistrationResult.registered,
        acceptMessage: (value) =>
            value is Map &&
            NotificationBinding.matches('customer', value['bindingId']),
      );
      await service.start(onMessage: (type, _) => received.add(type));
      messages.add({'type': 'PAYMENT_SUCCESS', 'bindingId': 'old'});
      messages.add({'type': 'TOP_UP_SUCCESS', 'bindingId': 'current'});
      await Future<void>.delayed(Duration.zero);
      expect(received, [NotificationType.topUpSuccess]);
      service.dispose();
      NotificationBinding.clear();
      await messages.close();
    },
  );
  test(
    'registers token through the existing authenticated API client',
    () async {
      final client = FakeClient(200);
      expect(
        await NotificationTokenApi(client).register('fake-token'),
        RegistrationResult.registered,
      );
      expect(client.requestBody, {'fcmToken': 'fake-token'});
    },
  );
  for (final entry in {
    401: RegistrationResult.unauthorized,
    404: RegistrationResult.missingProfile,
    500: RegistrationResult.failed,
  }.entries) {
    test('contains registration HTTP ${entry.key}', () async {
      expect(
        await NotificationTokenApi(FakeClient(entry.key)).register('fake'),
        entry.value,
      );
    });
  }
  test('malformed response fails safely', () async {
    expect(
      await NotificationTokenApi(FakeClient(200, body: 'invalid'))
          .register('fake'),
      RegistrationResult.failed,
    );
  });
  test('registration without a valid binding is rejected', () async {
    expect(
      await NotificationTokenApi(FakeClient(200, body: '{"success":true}'))
          .register('fake'),
      RegistrationResult.failed,
    );
  });
  test('only known types are accepted', () {
    for (final value in [null, '', 'SUCCESS', 1, {}, 'payment_success']) {
      expect(notificationType(value), isNull);
    }
    expect(notificationType('TOP_UP_SUCCESS'), NotificationType.topUpSuccess);
    expect(
      notificationType('PAYMENT_SUCCESS'),
      NotificationType.paymentSuccess,
    );
    expect(
      notificationType('PAYMENT_RECEIVED'),
      NotificationType.paymentReceived,
    );
  });

  for (final denied in [false, true]) {
    test('permission denied=$denied controls token registration', () async {
      var calls = 0;
      final service = NotificationService(
        requestPermission: () async => !denied,
        getToken: () async => 'fake',
        tokenChanges: const Stream.empty(),
        foregroundMessages: const Stream.empty(),
        openedMessages: const Stream.empty(),
        initialMessage: () async => null,
        isCurrentSession: () => true,
        registerToken: (_) async {
          calls++;
          return RegistrationResult.registered;
        },
      );
      expect(
        await service.start(onMessage: (_, _) {}),
        denied ? RegistrationResult.denied : RegistrationResult.registered,
      );
      expect(calls, denied ? 0 : 1);
      service.dispose();
    });
  }
  test(
    'refresh, foreground, open, malformed and disposed events are safe',
    () async {
      final tokens = StreamController<String>();
      final messages = StreamController<Object?>();
      final opens = StreamController<Object?>();
      final registered = <String>[];
      final received = <(NotificationType, bool)>[];
      var active = true;
      final service = NotificationService(
        requestPermission: () async => true,
        getToken: () async => 'first',
        tokenChanges: tokens.stream,
        foregroundMessages: messages.stream,
        openedMessages: opens.stream,
        initialMessage: () async => 'TOP_UP_SUCCESS',
        isCurrentSession: () => active,
        registerToken: (token) async {
          registered.add(token);
          return RegistrationResult.registered;
        },
      );
      await service.start(
        onMessage: (type, opened) => received.add((type, opened)),
      );
      tokens.add('second');
      messages.add('PAYMENT_SUCCESS');
      messages.add('invalid');
      opens.add('PAYMENT_RECEIVED');
      await Future<void>.delayed(Duration.zero);
      expect(registered, ['first', 'second']);
      expect(received, [
        (NotificationType.topUpSuccess, true),
        (NotificationType.paymentSuccess, false),
        (NotificationType.paymentReceived, true),
      ]);
      active = false;
      tokens.add('other-user');
      messages.add('PAYMENT_SUCCESS');
      await Future<void>.delayed(Duration.zero);
      expect(registered.length, 2);
      expect(received.length, 3);
      service.dispose();
      await tokens.close();
      await messages.close();
      await opens.close();
    },
  );
  test('registration exceptions do not escape startup', () async {
    final service = NotificationService(
      requestPermission: () async => true,
      getToken: () async => 'fake',
      tokenChanges: const Stream.empty(),
      foregroundMessages: const Stream.empty(),
      openedMessages: const Stream.empty(),
      initialMessage: () async => null,
      isCurrentSession: () => true,
      registerToken: (_) async => throw StateError('offline'),
    );
    expect(
      await service.start(onMessage: (_, _) {}),
      RegistrationResult.failed,
    );
    service.dispose();
  });
}
