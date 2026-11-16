import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';

import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/merchant/services/payment_intent_service.dart';
import 'package:vpay_mobile/features/profile/profile_screen.dart';
import 'package:vpay_mobile/core/widgets/navigation/vpay_tab_transition.dart';

const _merchantProfile = VPayUserProfile(
  uid: 'merchant-uid',
  name: 'Ravi Fernando',
  email: 'ravi@example.com',
  role: 'MERCHANT',
  status: 'ACTIVE',
  businessName: 'Central Canteen',
  businessCategory: 'Food & Beverage',
);

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentIntentService implements PaymentIntentService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'merchant transition preserves dashboard scroll and profile tab',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: _merchantProfile,
            authService: _FakeAuthService(),
            loadProfile: () async {
              loads++;
              return UserProfileResult.found(_merchantProfile);
            },
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(before, greaterThan(0));
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.byType(VPayTabTransition), findsOneWidget);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(loads, 1);
      await tester.tap(find.text('Dashboard').last);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(loads, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      final after = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(after, before);
      expect(tester.takeException(), isNull);
    },
  );

  test('profile parses the backend business name when present', () {
    final profile = VPayUserProfile.fromJson({
      'uid': 'merchant-uid',
      'name': 'Ravi Fernando',
      'email': 'ravi@example.com',
      'role': 'MERCHANT',
      'status': 'ACTIVE',
      'businessName': 'Central Canteen',
      'phone': '+94770000000',
      'businessCategory': 'Food & Beverage',
      'businessAddress': '1 Market Road',
    });

    expect(profile.businessName, 'Central Canteen');
    expect(profile.phone, '+94770000000');
    expect(profile.businessCategory, 'Food & Beverage');
    expect(profile.businessAddress, '1 Market Road');
  });

  testWidgets(
    'dashboard shows authenticated merchant and honest unavailable states',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MerchantDashboardScreen(profile: _merchantProfile),
        ),
      );

      expect(find.textContaining('Central Canteen'), findsOneWidget);
      expect(find.textContaining('Food & Beverage'), findsOneWidget);
      expect(find.text('VPay Merchant'), findsNothing);
      expect(find.textContaining('Ravi'), findsOneWidget);
      expect(find.text('Create Payment Request'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/logos/Long Logo Dark Mode.png',
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

  testWidgets('header shows safe fallbacks when business fields are absent', (
    tester,
  ) async {
    const incompleteProfile = VPayUserProfile(
      uid: 'merchant-uid',
      name: 'Ravi Fernando',
      email: 'ravi@example.com',
      role: 'MERCHANT',
      status: 'ACTIVE',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MerchantDashboardScreen(profile: incompleteProfile),
      ),
    );

    final details = tester.widget<Text>(
      find.byKey(const Key('merchantDashboardBusinessDetails')),
    );
    expect(details.data, contains('Business name not provided'));
    expect(details.data, contains('Business category not provided'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long business title stays within the narrow header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longProfile = VPayUserProfile(
      uid: 'merchant-uid',
      name: 'Ravi Fernando',
      email: 'ravi@example.com',
      role: 'MERCHANT',
      status: 'ACTIVE',
      businessName: 'A Very Long Merchant Business Name for Narrow Phones',
      businessCategory: 'Food & Beverage',
    );
    await tester.pumpWidget(
      const MaterialApp(home: MerchantDashboardScreen(profile: longProfile)),
    );

    final title = tester.widget<Text>(
      find.byKey(const Key('merchantDashboardBusinessDetails')),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('merchant header opens the authenticated Profile screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          authService: _FakeAuthService(),
          loadProfile: () async => UserProfileResult.found(_merchantProfile),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('merchantProfileAction')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Central Canteen'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('merchantDashboardBusinessDetails')),
      findsOneWidget,
    );
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
    final details = tester.widget<Text>(
      find.byKey(const Key('merchantDashboardBusinessDetails')),
    );
    expect(details.data, contains('Central Canteen Updated'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create tab returns to Dashboard selection after route closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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

  testWidgets(
    'Profile bottom tab replaces Terminal and displays merchant profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: _merchantProfile,
            authService: _FakeAuthService(),
            loadProfile: () async => UserProfileResult.found(_merchantProfile),
          ),
        ),
      );

      final navigation = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navigation.items.last.label, 'Profile');
      expect(find.text('Terminal'), findsNothing);

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Central Canteen'), findsWidgets);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        3,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(find.text('Create Payment Request'), findsOneWidget);
    },
  );
}
