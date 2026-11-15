import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_profile_screen.dart';

const _merchant = VPayUserProfile(
  uid: 'merchant-1',
  name: 'Amara Perera',
  email: 'amara@example.test',
  role: 'MERCHANT',
  status: 'ACTIVE',
  phone: '+94771234567',
  businessName: 'Blue Cafe',
  businessCategory: 'Food & Beverage',
  businessAddress: '12 Main Street',
);

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.signOutError});

  final Object? signOutError;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app({
  required _FakeAuthService auth,
  Future<UserProfileResult> Function()? loadProfile,
}) => MaterialApp(
  home: MerchantProfileScreen(
    profile: _merchant,
    authService: auth,
    loadProfile: loadProfile ?? () async => UserProfileResult.found(_merchant),
  ),
);

Future<void> _scrollToLogout(WidgetTester tester) async {
  final logout = find.byKey(const Key('merchantLogoutButton'));
  await tester.scrollUntilVisible(
    logout,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(logout);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders merchant account and business fields from profile', (
    tester,
  ) async {
    await tester.pumpWidget(_app(auth: _FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.text('Blue Cafe'), findsWidgets);
    expect(find.text('Food & Beverage'), findsWidgets);
    expect(find.text('Amara Perera'), findsOneWidget);
    expect(find.text('amara@example.test'), findsOneWidget);
    expect(find.text('+94771234567'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('12 Main Street'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('12 Main Street'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('shows missing values clearly', (tester) async {
    const incomplete = VPayUserProfile(
      uid: 'merchant-1',
      name: 'Amara Perera',
      email: 'amara@example.test',
      role: 'MERCHANT',
      status: 'ACTIVE',
    );
    await tester.pumpWidget(
      _app(
        auth: _FakeAuthService(),
        loadProfile: () async => UserProfileResult.found(incomplete),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not provided'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows loading then missing profile state', (tester) async {
    final pending = Completer<UserProfileResult>();
    await tester.pumpWidget(
      _app(auth: _FakeAuthService(), loadProfile: () => pending.future),
    );
    expect(find.byKey(const Key('merchantProfileLoading')), findsOneWidget);

    pending.complete(const UserProfileResult.missing());
    await tester.pumpAndSettle();
    expect(
      find.text('Merchant profile details are unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a retry action when profile loading fails', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        auth: _FakeAuthService(),
        loadProfile: () async {
          calls++;
          throw StateError('network');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchantProfileRetry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchantProfileRetry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('logout requires confirmation and cancellation keeps session', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pumpAndSettle();

    await _scrollToLogout(tester);
    await tester.tap(find.byKey(const Key('merchantLogoutButton')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(auth.signOutCalls, 0);
    await tester.tap(find.byKey(const Key('merchantLogoutCancel')));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);
    expect(find.text('Blue Cafe'), findsOneWidget);
  });

  testWidgets('confirmed logout calls the shared sign-out service', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pumpAndSettle();

    await _scrollToLogout(tester);
    await tester.tap(find.byKey(const Key('merchantLogoutButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchantLogoutConfirm')));
    await tester.pump();

    expect(auth.signOutCalls, 1);
  });

  testWidgets('logout failure is visible and profile remains usable', (
    tester,
  ) async {
    final auth = _FakeAuthService(signOutError: StateError('network'));
    await tester.pumpWidget(_app(auth: auth));
    await tester.pumpAndSettle();

    await _scrollToLogout(tester);
    await tester.tap(find.byKey(const Key('merchantLogoutButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchantLogoutConfirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchantLogoutError')), findsOneWidget);
    expect(find.text('Blue Cafe'), findsOneWidget);
    expect(find.byKey(const Key('merchantLogoutButton')), findsOneWidget);
  });
}
