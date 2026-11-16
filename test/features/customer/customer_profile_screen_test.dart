import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/customer/screens/customer_profile_screen.dart';

void main() {
  testWidgets('customer profile shows account details and signs out', (
    tester,
  ) async {
    var signOutCalls = 0;
    const profile = VPayUserProfile(
      uid: 'customer-1',
      name: 'Kasun Perera',
      email: 'kasun@example.com',
      phone: '0712345678',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerProfileScreen(
            profile: profile,
            onSignOut: () => signOutCalls++,
          ),
        ),
      ),
    );

    expect(find.text('Kasun Perera'), findsOneWidget);
    expect(find.text('kasun@example.com'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customerProfileSignOut')));
    expect(signOutCalls, 1);
  });
}
