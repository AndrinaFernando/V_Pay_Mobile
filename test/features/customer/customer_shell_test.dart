import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';

const _customerProfile = VPayUserProfile(
  uid: 'cust-1',
  name: 'Nimal Perera',
  email: 'nimal@university.test',
  role: 'CUSTOMER',
  status: 'ACTIVE',
  phone: '+94771112233',
);

class _FakeAuthService implements AuthService {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('customer shell has Home, Scan & Pay, Activity, Profile tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _customerProfile,
          authService: _FakeAuthService(),
        ),
      ),
    );

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.length, 4);
    expect(nav.items[0].label, 'Home');
    expect(nav.items[1].label, 'Scan & Pay');
    expect(nav.items[2].label, 'Activity');
    expect(nav.items[3].label, 'Profile');
  });

  testWidgets('Profile tab shows the unified profile screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _customerProfile,
          authService: _FakeAuthService(),
        ),
      ),
    );

    // Tap Profile tab
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    // Unified profile screen should be visible
    expect(find.byKey(const Key('profileName')), findsOneWidget);
    expect(find.text('Nimal Perera'), findsOneWidget);
    expect(find.text('nimal@university.test'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
  });

  testWidgets('Scan & Pay and Activity tabs still show coming soon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _customerProfile,
          authService: _FakeAuthService(),
        ),
      ),
    );

    // Tap Scan & Pay
    await tester.tap(find.text('Scan & Pay').last);
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
    expect(find.textContaining('Nimal'), findsOneWidget);

    // Tap Activity
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('customer profile logout calls AuthService.signOut', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(profile: _customerProfile, authService: auth),
      ),
    );

    // Navigate to Profile tab
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    // Tap Log Out
    await tester.scrollUntilVisible(
      find.byKey(const Key('profileLogout')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profileScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('profileLogout')));
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.byKey(const Key('logoutConfirmButton')));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
  });
}
