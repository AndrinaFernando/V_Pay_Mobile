import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_payment_intent.dart';
import 'package:vpay_mobile/features/merchant/services/payment_intent_service.dart';

const _merchantProfile = VPayUserProfile(
  uid: 'merchant-uid',
  name: 'Ravi Fernando',
  email: 'ravi@example.com',
  role: 'MERCHANT',
  status: 'ACTIVE',
  businessName: 'Central Canteen',
);

class _FakePaymentIntentService implements PaymentIntentService {
  const _FakePaymentIntentService();

  @override
  Future<MerchantPaymentIntent> createPaymentIntent({
    required int amountMinor,
    String? description,
  }) => throw UnimplementedError();

  @override
  Future<MerchantPaymentIntent> getPaymentIntent({
    required String paymentReference,
  }) => throw UnimplementedError();
}

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

  testWidgets(
    'dashboard shows authenticated merchant and honest unavailable states',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MerchantDashboardScreen(profile: _merchantProfile),
        ),
      );

      expect(find.text('Central Canteen'), findsOneWidget);
      expect(find.textContaining('Ravi'), findsOneWidget);
      expect(find.text('Create Payment Request'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/logos/Logo Blue V2.0.png',
        ),
        findsOneWidget,
      );
      expect(find.text('Balance details aren’t available yet'), findsOneWidget);
      expect(find.text('No received payments to show yet'), findsOneWidget);
      expect(find.text('48,250.00'), findsNothing);
      expect(find.text('18,420.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create request action uses its supplied callback', (
    tester,
  ) async {
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

  testWidgets('pull to refresh reloads the authenticated merchant profile', (
    tester,
  ) async {
    const refreshedProfile = VPayUserProfile(
      uid: 'merchant-uid',
      name: 'Ravi Fernando',
      email: 'ravi@example.com',
      role: 'MERCHANT',
      status: 'ACTIVE',
      businessName: 'Central Canteen Updated',
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          loadProfile: () async {
            calls++;
            return UserProfileResult.found(refreshedProfile);
          },
        ),
      ),
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 350));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(calls, 1);
    expect(find.text('Central Canteen Updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create tab returns to Dashboard selection after route closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          paymentIntentService: _FakePaymentIntentService(),
        ),
      ),
    );

    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();
    expect(find.text('Create Payment Request'), findsOneWidget);

    Navigator.of(tester.element(find.text('Create Payment Request'))).pop();
    await tester.pumpAndSettle();

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.currentIndex, 0);
  });
}
