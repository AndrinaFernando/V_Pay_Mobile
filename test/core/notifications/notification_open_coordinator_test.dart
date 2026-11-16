import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/notifications/notification_service.dart';
import 'package:vpay_mobile/core/notifications/notification_open_coordinator.dart';
import 'package:vpay_mobile/core/notifications/notification_scope.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/app_access_gate.dart';
import 'package:vpay_mobile/core/security/local_auth_service.dart';

class FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalAuth implements LocalAuthService {
  Completer<bool> response = Completer<bool>();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> authenticateForAppAccess() => response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late String? uid;
  late StreamController<String?> sessions;
  late StreamController<NotificationOpen> opens;
  late Completer<NotificationOpen?> initial;
  late NotificationOpenCoordinator coordinator;
  setUp(() {
    uid = 'a';
    sessions = StreamController<String?>.broadcast(sync: true);
    opens = StreamController<NotificationOpen>.broadcast(sync: true);
    initial = Completer<NotificationOpen?>();
    coordinator = NotificationOpenCoordinator(
      currentUid: () => uid,
      sessions: sessions.stream,
      opened: opens.stream,
      initial: () => initial.future,
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await sessions.close();
    await opens.close();
  });
  test('coalesces locked taps and consumes only once after unlock', () {
    opens.add(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    opens.add(const NotificationOpen('2', 'TOP_UP_SUCCESS'));
    expect(coordinator.take('CUSTOMER'), NotificationType.topUpSuccess);
    expect(coordinator.take('CUSTOMER'), isNull);
    opens.add(const NotificationOpen('2', 'TOP_UP_SUCCESS'));
    expect(coordinator.take('CUSTOMER'), isNull);
  });
  test('account switch and signed out events discard pending intent', () {
    opens.add(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    uid = 'b';
    sessions.add(uid);
    expect(coordinator.take('CUSTOMER'), isNull);
    uid = null;
    sessions.add(uid);
    opens.add(const NotificationOpen('2', 'PAYMENT_SUCCESS'));
    uid = 'a';
    sessions.add(uid);
    expect(coordinator.take('CUSTOMER'), isNull);
  });
  test('delayed initial message cannot cross an account change', () async {
    uid = 'b';
    sessions.add(uid);
    initial.complete(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.take('CUSTOMER'), isNull);
  });
  test('initial and opened delivery of same ID refresh only once', () async {
    opens.add(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    expect(coordinator.take('CUSTOMER'), isNotNull);
    initial.complete(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.take('CUSTOMER'), isNull);
  });
  testWidgets('actual access gate retains taps across its background lock', (
    tester,
  ) async {
    final local = FakeLocalAuth();
    var mounts = 0;
    final service = NotificationService(
      requestPermission: () async => true,
      getToken: () async => 'token',
      tokenChanges: const Stream.empty(),
      foregroundMessages: const Stream.empty(),
      openedMessages: const Stream.empty(),
      initialMessage: () async => null,
      isCurrentSession: () => true,
      registerToken: (_) async => RegistrationResult.registered,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccessGate(
          authService: FakeAuth(),
          localAuthService: local,
          child: NotificationScope(
            auth: FakeAuth(),
            role: 'CUSTOMER',
            opens: coordinator,
            retainService: true,
            serviceFactory: (_) => service,
            child: Builder(
              builder: (_) {
                mounts++;
                return const Scaffold(body: Text('Private'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    opens.add(const NotificationOpen('first', 'PAYMENT_SUCCESS'));
    await tester.pump();
    expect(find.text('Private'), findsNothing);
    local.response.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsOneWidget);
    local.response = Completer<bool>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 61));
    // Paused apps do not render the lock until frames resume.
    opens.add(const NotificationOpen('locked', 'PAYMENT_SUCCESS'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('Private'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    local.response.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsOneWidget);
    final count = mounts;
    opens.add(const NotificationOpen('locked', 'PAYMENT_SUCCESS'));
    await tester.pumpAndSettle();
    expect(mounts, count);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  test('wrong role and unknown types are discarded', () {
    opens.add(const NotificationOpen('1', 'PAYMENT_RECEIVED'));
    expect(coordinator.take('CUSTOMER'), isNull);
    opens.add(const NotificationOpen('2', 'unknown'));
    expect(coordinator.take('MERCHANT'), isNull);
  });
  testWidgets('locked UI reveals nothing and unlocked scope refreshes once', (
    tester,
  ) async {
    var builds = 0;
    Widget view(bool unlocked) => MaterialApp(
      home: unlocked
          ? NotificationScope(
              auth: FakeAuth(),
              role: 'CUSTOMER',
              opens: coordinator,
              serviceFactory: (_) => NotificationService(
                requestPermission: () async => false,
                getToken: () async => null,
                tokenChanges: const Stream.empty(),
                foregroundMessages: const Stream.empty(),
                openedMessages: const Stream.empty(),
                initialMessage: () async => null,
                isCurrentSession: () => true,
                registerToken: (_) async => RegistrationResult.registered,
              ),
              child: Builder(
                builder: (_) {
                  builds++;
                  return const Scaffold(body: Text('Protected home'));
                },
              ),
            )
          : const Scaffold(body: Text('Locked')),
    );
    await tester.pumpWidget(view(false));
    opens.add(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    await tester.pump();
    expect(find.text('Protected home'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(view(true));
    await tester.pump();
    expect(find.text('Protected home'), findsOneWidget);
    final count = builds;
    opens.add(const NotificationOpen('1', 'PAYMENT_SUCCESS'));
    await tester.pump();
    await tester.pump();
    expect(builds, count);
    await tester.pumpWidget(const SizedBox());
  });
}
