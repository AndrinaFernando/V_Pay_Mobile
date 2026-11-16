import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/merchant/services/payment_intent_service.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_qr_scanner_screen.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/profile/account_details_screen.dart';
import 'package:vpay_mobile/features/profile/edit_profile_screen.dart';
import 'package:vpay_mobile/features/topup/screens/topup_screen.dart';
import 'package:vpay_mobile/features/topup/screens/topup_history_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

import '../../support/fake_dashboard_services.dart';

class _Auth implements AuthService {
  int signOutCalls = 0;
  @override
  Future<void> signOut() async => signOutCalls++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TopUps implements TopUpService {
  @override
  Future<List<TopUp>> list() async => [];
  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();
  @override
  Future<TopUp> get(String id) => throw UnimplementedError();
}

class _PaymentIntents implements PaymentIntentService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _shell(bool merchant, _Auth auth) {
  final profile = VPayUserProfile(
    uid: 'navigation-test',
    name: 'Test User',
    email: 'test@example.com',
    role: merchant ? 'MERCHANT' : 'CUSTOMER',
    status: 'ACTIVE',
  );
  return merchant
      ? MerchantDashboardScreen(
          profile: profile,
          authService: auth,
          loadProfile: () async => UserProfileResult.found(profile),
          paymentIntentService: _PaymentIntents(),
          merchantBalanceService: FakeDashboardMerchantBalanceService(),
          merchantReceivedPaymentsService:
              FakeDashboardReceivedPaymentsService(),
        )
      : CustomerShell(
          profile: profile,
          authService: auth,
          cardApiService: FakeDashboardCardService(),
          transactionService: FakeDashboardTransactionService(),
          topUpService: _TopUps(),
          qrScannerBuilder: (
            context, {
            required onRawValue,
            required errorBuilder,
          }) => const SizedBox(),
        );
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

int _selected(WidgetTester tester) => tester
    .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
    .currentIndex;

void main() {
  for (final merchant in [false, true]) {
    final role = merchant ? 'Merchant' : 'Customer';
    final activity = merchant ? 'Payments' : 'Activity';
    final root = merchant ? 'Dashboard' : 'Home';

    testWidgets('$role Back retraces tabs and permits root exit', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: _shell(merchant, _Auth())),
      );
      await tester.pumpAndSettle();
      expect(await navigator.currentState!.maybePop(), isFalse);
      await _tab(tester, activity);
      await _tab(tester, 'Profile');
      await _tab(tester, 'Profile'); // Reselecting a tab adds no history.
      final route = ModalRoute.of(
        tester.element(find.byType(BottomNavigationBar)),
      )!;
      expect(route.popDisposition, RoutePopDisposition.doNotPop);
      await _back(tester);
      expect(_selected(tester), 2);
      await _back(tester);
      expect(_selected(tester), 0);
      expect(route.popDisposition, RoutePopDisposition.bubble);
      expect(await navigator.currentState!.maybePop(), isFalse);

      // Explicitly revisiting Home is still a visit, not a history reset.
      await _tab(tester, activity);
      await _tab(tester, root);
      await _back(tester);
      expect(_selected(tester), 2);
      await _back(tester);
      expect(_selected(tester), 0);
    });

    testWidgets('$role profile AppBar retraces the previous tab', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: _shell(merchant, _Auth())));
      await tester.pumpAndSettle();
      await _tab(tester, activity);
      await _tab(tester, 'Profile');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_selected(tester), 2);
      await _back(tester);
      expect(_selected(tester), 0);
    });

    testWidgets('$role profile details close before tab history', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: _shell(merchant, _Auth())));
      await tester.pumpAndSettle();
      await _tab(tester, activity);
      await _tab(tester, 'Profile');
      for (final key in ['profileAccountDetails', 'profileEditProfile']) {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          find.byType(
            key == 'profileAccountDetails'
                ? AccountDetailsScreen
                : EditProfileScreen,
          ),
          findsOneWidget,
        );
        await _back(tester);
        expect(_selected(tester), 3);
      }
      await _back(tester);
      expect(_selected(tester), 2);
    });

    testWidgets('$role logout dialog and bottom sheet close before tabs', (
      tester,
    ) async {
      final auth = _Auth();
      await tester.pumpWidget(MaterialApp(home: _shell(merchant, auth)));
      await tester.pumpAndSettle();
      await _tab(tester, activity);
      await _tab(tester, 'Profile');
      final logout = find.byKey(const Key('profileLogout'));
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await _back(tester);
      expect(find.text('Log out?'), findsNothing);
      expect(auth.signOutCalls, 0);
      expect(_selected(tester), 3);
      final context = tester.element(find.byType(BottomNavigationBar));
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 100, child: Text('Test sheet')),
      );
      await tester.pumpAndSettle();
      await _back(tester);
      expect(find.text('Test sheet'), findsNothing);
      expect(_selected(tester), 3);
      await _back(tester);
      expect(_selected(tester), 2);
    });
  }

  testWidgets('Customer scanner closes before Scan & Pay tab history', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _shell(false, _Auth())));
    await tester.pumpAndSettle();
    await _tab(tester, 'Scan & Pay');
    await _tab(tester, 'Profile');
    await _back(tester);
    expect(_selected(tester), 1);
    await tester.tap(find.byKey(const ValueKey('scanMerchantQrButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);
    await _back(tester);
    expect(find.byType(CustomerQrScannerScreen), findsNothing);
    expect(_selected(tester), 1);
    await _back(tester);
    expect(_selected(tester), 0);
  });

  testWidgets('Home Top Up History closes to Top Up then Home', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _shell(false, _Auth())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Top Up').last);
    await tester.tap(find.text('Top Up').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top-up history'));
    await tester.pumpAndSettle();
    expect(find.byType(TopUpHistoryScreen), findsOneWidget);
    await _back(tester);
    expect(find.byType(TopUpScreen), findsOneWidget);
    expect(find.byType(TopUpHistoryScreen), findsNothing);
    await _back(tester);
    expect(_selected(tester), 0);
  });

  testWidgets('Merchant Create returns to Payments before Dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _shell(true, _Auth())));
    await tester.pumpAndSettle();
    await _tab(tester, 'Payments');
    await _tab(tester, 'Create');
    expect(find.text('Request a payment'), findsOneWidget);
    await _back(tester);
    expect(_selected(tester), 2);
    await _back(tester);
    expect(_selected(tester), 0);
  });
}
