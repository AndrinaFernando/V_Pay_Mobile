import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/notifications/notification_open_coordinator.dart';
import 'package:vpay_mobile/core/notifications/notification_scope.dart';
import 'package:vpay_mobile/core/notifications/notification_service.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/topup/screens/topup_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class _Auth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TopUps implements TopUpService {
  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();
  @override
  Future<TopUp> get(String id) => throw UnimplementedError();
  @override
  Future<List<TopUp>> list() async => const [];
}

void main() {
  testWidgets('notification refresh preserves the Top Up route', (
    tester,
  ) async {
    final opens = StreamController<NotificationOpen>.broadcast();
    final sessions = StreamController<String?>.broadcast();
    final coordinator = NotificationOpenCoordinator(
      currentUid: () => 'customer',
      sessions: sessions.stream,
      opened: opens.stream,
      initial: () async => null,
    );
    final service = NotificationService(
      requestPermission: () async => false,
      getToken: () async => null,
      tokenChanges: const Stream.empty(),
      foregroundMessages: const Stream.empty(),
      openedMessages: const Stream.empty(),
      initialMessage: () async => null,
      isCurrentSession: () => true,
      registerToken: (_) async => RegistrationResult.denied,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScope(
          auth: _Auth(),
          role: 'CUSTOMER',
          opens: coordinator,
          serviceFactory: (_) => service,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TopUpScreen(service: _TopUps()),
                  ),
                ),
                child: const Text('Dashboard'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    opens.add(const NotificationOpen('new', 'TOP_UP_SUCCESS'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Continue to Rupio'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    service.dispose();
    await opens.close();
    await sessions.close();
  });
}
