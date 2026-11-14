import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';

const _merchantProfile = VPayUserProfile(
  uid: 'merchant-uid',
  name: 'Ravi Fernando',
  email: 'ravi@example.com',
  role: 'MERCHANT',
  status: 'ACTIVE',
  businessName: 'Central Canteen',
);

void main() {
  test('profile parses the backend business name when present', () {
    final profile = VPayUserProfile.fromJson({
      'uid': 'merchant-uid',
      'name': 'Ravi Fernando',
      'email': 'ravi@example.com',
      'role': 'MERCHANT',
      'status': 'ACTIVE',
      'businessName': 'Central Canteen',
    });

    expect(profile.businessName, 'Central Canteen');
  });

  testWidgets('dashboard shows authenticated merchant and honest unavailable states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MerchantDashboardScreen(profile: _merchantProfile)),
    );

    expect(find.text('Central Canteen'), findsOneWidget);
    expect(find.textContaining('Ravi'), findsOneWidget);
    expect(find.text('Create Payment Request'), findsOneWidget);
    expect(find.text('Balance details aren’t available yet'), findsOneWidget);
    expect(find.text('No received payments to show yet'), findsOneWidget);
    expect(find.text('48,250.00'), findsNothing);
    expect(find.text('18,420.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create request action uses its supplied callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          onCreatePaymentRequest: () => pressed = true,
        ),
      ),
    );

    await tester.tap(find.text('Create Payment Request'));
    expect(pressed, isTrue);
  });
}
