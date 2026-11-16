import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/notifications/notification_binding.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';

class _User implements User {
  @override
  String get uid => 'customer';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FirebaseAuth implements FirebaseAuth {
  int signOutCalls = 0;
  @override
  User? get currentUser => signOutCalls == 0 ? _User() : null;
  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(NotificationBinding.clear);

  test(
    'Firebase sign-out and binding cleanup proceed after unregister failure',
    () async {
      NotificationBinding.set('customer', 'token', 'binding');
      final firebase = _FirebaseAuth();
      final auth = AuthService(
        auth: firebase,
        unregisterNotificationToken: (token, binding) async {
          expect((token, binding), ('token', 'binding'));
          expect(NotificationBinding.matches('customer', 'binding'), isFalse);
          throw StateError('offline');
        },
      );
      await auth.signOut();
      expect(firebase.signOutCalls, 1);
      expect(NotificationBinding.matches('customer', 'binding'), isFalse);
    },
  );

  test('Firebase sign-out proceeds when unregister never responds', () async {
    NotificationBinding.set('customer', 'token', 'binding');
    final firebase = _FirebaseAuth();
    final pending = Completer<void>();
    final auth = AuthService(
      auth: firebase,
      unregisterNotificationToken: (_, _) => pending.future,
      notificationUnregisterTimeout: const Duration(milliseconds: 10),
    );
    await auth.signOut();
    expect(firebase.signOutCalls, 1);
    expect(NotificationBinding.matches('customer', 'binding'), isFalse);
  });
}
