import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_gate.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/auth/screens/login_screen.dart';
import 'package:vpay_mobile/features/auth/services/user_api_service.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/profile/profile_screen.dart';

import '../../support/fake_dashboard_services.dart';

class _FakeUser implements User {
  @override
  String get uid => 'merchant-uid';

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  final StreamController<User?> _changes = StreamController<User?>.broadcast();
  User? user = _FakeUser();

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(null);
  }

  void emitSignedIn() => _changes.add(user);

  Future<void> close() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserApiService implements UserApiService {
  _FakeUserApiService({this.role = 'MERCHANT'});

  final String role;
  @override
  Future<UserProfileResult> getCurrentUserProfile() async =>
      UserProfileResult.found(
        VPayUserProfile(
          uid: 'merchant-uid',
          name: 'Merchant User',
          email: 'merchant@example.test',
          role: role,
          status: 'ACTIVE',
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final role in ['CUSTOMER', 'MERCHANT']) {
    testWidgets(
      '$role profile logout reveals AuthGate and prevents back access',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/local_auth'),
          (_) async => true,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            null,
          ),
        );
        final auth = _FakeAuthService();
        addTearDown(auth.close);
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              authService: auth,
              userApiService: _FakeUserApiService(role: role),
              cardApiService: FakeDashboardCardService(),
              customerTransactionService: FakeDashboardTransactionService(),
              merchantBalanceService: FakeDashboardMerchantBalanceService(),
              merchantReceivedPaymentsService:
                  FakeDashboardReceivedPaymentsService(),
            ),
          ),
        );
        auth.emitSignedIn();
        await tester.pumpAndSettle();
        if (role == 'MERCHANT') {
          // Exercise the pushed header route as well as the confirmation modal.
          await tester.tap(find.byKey(const Key('merchantProfileAction')));
        } else {
          await tester.tap(find.text('Profile').last);
        }
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        final logout = find.byKey(const Key('profileLogout'));
        await tester.scrollUntilVisible(
          logout,
          150,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(logout);
        await tester.pumpAndSettle();
        await tester.tap(logout);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('logoutConfirmButton')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ProfileScreen), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  }

  testWidgets('AuthGate replaces protected merchant route after sign-out', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: auth,
          userApiService: _FakeUserApiService(),
          cardApiService: FakeDashboardCardService(),
          customerTransactionService: FakeDashboardTransactionService(),
          merchantBalanceService: FakeDashboardMerchantBalanceService(),
          merchantReceivedPaymentsService:
              FakeDashboardReceivedPaymentsService(),
        ),
      ),
    );
    auth.emitSignedIn();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The access gate may cover the child while device authentication is
    // checked, but AuthGate owns the protected merchant subtree.
    expect(find.byType(LoginScreen), findsNothing);

    await auth.signOut();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MerchantDashboardScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MerchantDashboardScreen), findsNothing);
    await auth.close();
  });
}
