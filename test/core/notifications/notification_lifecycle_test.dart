import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/notifications/notification_service.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';

class FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<String> tokens;
  late StreamController<Object?> messages;
  late bool active;
  late NotificationService service;
  NotificationService create(
    Future<RegistrationResult> Function(String) register, {
    Future<String?> Function()? getToken,
    Future<bool> Function()? permission,
  }) {
    return service = NotificationService(
      requestPermission: permission ?? () async => true,
      getToken: getToken ?? () async => 'first',
      tokenChanges: tokens.stream,
      foregroundMessages: messages.stream,
      openedMessages: const Stream.empty(),
      initialMessage: () async => null,
      isCurrentSession: () => active,
      registerToken: register,
    );
  }

  setUp(() {
    tokens = StreamController<String>.broadcast();
    messages = StreamController<Object?>.broadcast();
    active = true;
  });
  tearDown(() async {
    service.dispose();
    await tokens.close();
    await messages.close();
  });

  test(
    'serializes overlapping refreshes and deduplicates successful tokens',
    () async {
      final first = Completer<RegistrationResult>();
      final calls = <String>[];
      create((token) async {
        calls.add(token);
        return token == 'first'
            ? await first.future
            : RegistrationResult.registered;
      });
      final startup = service.start(onMessage: (_, _) {});
      await tick();
      tokens.add('first');
      tokens.add('second');
      tokens.add('third');
      tokens.add('third');
      await tick();
      expect(calls, ['first']);
      first.complete(RegistrationResult.registered);
      await startup;
      await tick();
      expect(calls, ['first', 'second', 'third']);
      tokens.add('third');
      await tick();
      expect(calls.length, 3);
    },
  );

  test('refresh supersedes a delayed getToken snapshot', () async {
    final snapshot = Completer<String?>();
    final calls = <String>[];
    create((token) async {
      calls.add(token);
      return RegistrationResult.registered;
    }, getToken: () => snapshot.future);
    final startup = service.start(onMessage: (_, _) {});
    await tick();
    tokens.add('newest');
    await tick();
    snapshot.complete('old');
    await startup;
    expect(calls, ['newest']);
  });

  test('failed registration can recover with the identical token', () async {
    var attempts = 0;
    create(
      (_) async => ++attempts == 1
          ? RegistrationResult.failed
          : RegistrationResult.registered,
    );
    expect(
      await service.start(onMessage: (_, _) {}),
      RegistrationResult.failed,
    );
    tokens.add('first');
    await tick();
    expect(attempts, 2);
    await service.recover();
    expect(attempts, 2);
  });

  test(
    'logout during registration prevents queued sends and late callbacks',
    () async {
      final response = Completer<RegistrationResult>();
      final calls = <String>[];
      var received = 0;
      create((token) {
        calls.add(token);
        return response.future;
      });
      final startup = service.start(onMessage: (_, _) => received++);
      await tick();
      tokens.add('queued');
      await tick();
      active = false;
      tokens.add('after-logout');
      messages.add('PAYMENT_SUCCESS');
      response.complete(RegistrationResult.registered);
      expect(await startup, RegistrationResult.unavailable);
      await tick();
      expect(calls, ['first']);
      expect(received, 0);
    },
  );

  test('reusing service after unlock preserves deduplication and replaces callbacks', () async {
    var sends = 0;
    var oldMessages = 0;
    var newMessages = 0;
    create((_) async {
      sends++;
      return RegistrationResult.registered;
    });
    await service.start(onMessage: (_, _) => oldMessages++);
    service.detachMessages();
    messages.add('PAYMENT_SUCCESS');
    await tick();
    await service.start(onMessage: (_, _) => newMessages++);
    messages.add('PAYMENT_SUCCESS');
    await tick();
    expect(sends, 1);
    expect(oldMessages, 0);
    expect(newMessages, 1);
  });

  test('logout while retrieving token prevents any registration', () async {
    final token = Completer<String?>();
    var sends = 0;
    create((_) async {
      sends++;
      return RegistrationResult.registered;
    }, getToken: () => token.future);
    final startup = service.start(onMessage: (_, _) {});
    await tick();
    active = false;
    token.complete('late');
    expect(await startup, RegistrationResult.unavailable);
    expect(sends, 0);
  });

  test('events after disposal do nothing', () async {
    var calls = 0;
    var received = 0;
    create((_) async {
      calls++;
      return RegistrationResult.registered;
    });
    await service.start(onMessage: (_, _) => received++);
    service.dispose();
    tokens.add('late');
    messages.add('PAYMENT_SUCCESS');
    await tick();
    expect(calls, 1);
    expect(received, 0);
  });

  test('permission and SDK failures recover on explicit trigger without a retry loop', () async {
    var checks = 0;
    var calls = 0;
    create(
      (_) async {
        calls++;
        return RegistrationResult.registered;
      },
      permission: () async {
        checks++;
        if (checks == 1) throw StateError('SDK');
        return checks > 2;
      },
    );
    expect(
      await service.start(onMessage: (_, _) {}),
      RegistrationResult.failed,
    );
    expect(await service.recover(), RegistrationResult.denied);
    expect(calls, 0);
    expect(await service.recover(), RegistrationResult.registered);
    expect(checks, 3);
    expect(calls, 1);
  });
}
