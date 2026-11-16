import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_balance.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_payment_intent.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_received_payment.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/merchant/screens/payment_intent_qr_screen.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_balance_service.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_received_payments_service.dart';
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
  _FakePaymentIntentService({
    this.createdIntent,
    this.statusResponses = const [],
  });

  final MerchantPaymentIntent? createdIntent;
  final List<MerchantPaymentIntent> statusResponses;
  int statusCalls = 0;

  @override
  Future<MerchantPaymentIntent> createPaymentIntent({
    required int amountMinor,
    String? description,
  }) async {
    if (createdIntent == null) throw StateError('No payment intent fixture.');
    return createdIntent!;
  }

  @override
  Future<MerchantPaymentIntent> getPaymentIntent({
    required String paymentReference,
  }) async {
    if (statusResponses.isEmpty) throw StateError('No status fixture.');
    final result =
        statusResponses[statusCalls.clamp(0, statusResponses.length - 1)];
    statusCalls++;
    return result;
  }

  @override
  Future<List<MerchantPaymentIntent>> listPaymentIntents({
    int limit = 20,
  }) async => const [];
}

class _FakeMerchantBalanceService implements MerchantBalanceService {
  _FakeMerchantBalanceService({this.load});

  final Future<MerchantBalance> Function()? load;
  int calls = 0;

  @override
  Future<MerchantBalance> getMerchantBalance() {
    calls++;
    return load?.call() ??
        Future.value(
          const MerchantBalance(balanceMinor: 42345, currency: 'LKR'),
        );
  }
}

class _FakeMerchantReceivedPaymentsService
    implements MerchantReceivedPaymentsService {
  _FakeMerchantReceivedPaymentsService({this.payments = const [], this.load});

  final List<MerchantReceivedPayment> payments;
  final Future<List<MerchantReceivedPayment>> Function()? load;
  int calls = 0;
  int? requestedLimit;

  @override
  Future<List<MerchantReceivedPayment>> getReceivedPayments({int limit = 20}) {
    calls++;
    requestedLimit = limit;
    return load?.call() ?? Future.value(payments);
  }
}

MerchantReceivedPayment _receivedPayment({
  String id = 'qr-payment--reference-123',
  String reference = 'reference-123',
  int amountMinor = 125050,
  DateTime? createdAt,
}) {
  return MerchantReceivedPayment(
    transactionId: id,
    paymentReference: reference,
    amountMinor: amountMinor,
    currency: 'LKR',
    status: 'SUCCESS',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 15, 10, 30),
  );
}

void main() {
  testWidgets('system Back closes QR then Create before tab history', (
    tester,
  ) async {
    final now = DateTime.now();
    final pending = MerchantPaymentIntent(
      paymentReference: 'back-navigation-request',
      merchantName: 'Central Canteen',
      amountMinor: 1000,
      currency: 'LKR',
      status: 'PENDING',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
          paymentIntentService: _FakePaymentIntentService(
            createdIntent: pending,
            statusResponses: [pending],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '10.00',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('createPaymentRequestButton')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('createPaymentRequestButton')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(PaymentIntentQrScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Request a payment'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
  });

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
            merchantBalanceService: _FakeMerchantBalanceService(),
            merchantReceivedPaymentsService:
                _FakeMerchantReceivedPaymentsService(),
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
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: _merchantProfile,
            merchantBalanceService: _FakeMerchantBalanceService(),
            merchantReceivedPaymentsService:
                _FakeMerchantReceivedPaymentsService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

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
      expect(find.text('LKR 423.45'), findsOneWidget);
      expect(find.text('No received payments to show yet'), findsOneWidget);
      expect(find.text('48,250.00'), findsNothing);
      expect(find.text('18,420.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('received payments load and show confirmed ledger fields', (
    tester,
  ) async {
    final pending = Completer<List<MerchantReceivedPayment>>();
    final service = _FakeMerchantReceivedPaymentsService(
      load: () => pending.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService: service,
        ),
      ),
    );
    expect(
      find.byKey(const Key('merchantRecentPaymentsSkeleton')),
      findsOneWidget,
    );

    pending.complete([_receivedPayment()]);
    await tester.pumpAndSettle();
    expect(find.text('LKR 1,250.50'), findsOneWidget);
    expect(find.text('Ref: reference-123'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(service.requestedLimit, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('received payment retry recovers from a network error', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeMerchantReceivedPaymentsService(
      load: () async {
        attempts++;
        if (attempts == 1) throw const ApiException(503, 'Offline');
        return [_receivedPayment()];
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('merchantRecentPaymentsError')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('retryMerchantReceivedPayments')),
    );
    await tester.tap(find.byKey(const Key('retryMerchantReceivedPayments')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Ref: reference-123'), findsOneWidget);
  });

  testWidgets('View all opens the merchant received payments list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService: _FakeMerchantReceivedPaymentsService(
            payments: [_receivedPayment()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewAllMerchantPayments')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('merchantReceivedPaymentsTitle')),
      findsOneWidget,
    );
    expect(find.text('Ref: reference-123'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
  });

  testWidgets('shows a balance skeleton and then the fetched amount', (
    tester,
  ) async {
    final pending = Completer<MerchantBalance>();
    final service = _FakeMerchantBalanceService(load: () => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: service,
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
        ),
      ),
    );

    expect(find.byKey(const Key('merchantBalanceSkeleton')), findsOneWidget);
    pending.complete(
      const MerchantBalance(balanceMinor: 8875, currency: 'LKR'),
    );
    await tester.pumpAndSettle();
    expect(find.text('LKR 88.75'), findsOneWidget);
    expect(find.byKey(const Key('merchantBalanceSkeleton')), findsNothing);
  });

  testWidgets('shows a retry action after a balance request error', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeMerchantBalanceService(
      load: () async {
        attempts++;
        if (attempts == 1) throw const ApiException(500, 'Unavailable');
        return const MerchantBalance(balanceMinor: 8800, currency: 'LKR');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: service,
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchantBalanceError')), findsOneWidget);
    expect(find.text('LKR 88.00'), findsNothing);
    await tester.tap(find.byKey(const Key('merchantBalanceRetry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('LKR 88.00'), findsOneWidget);
    expect(find.byKey(const Key('merchantBalanceError')), findsNothing);
  });

  testWidgets('refreshes balance when the app returns to the foreground', (
    tester,
  ) async {
    final service = _FakeMerchantBalanceService();
    final receivedPaymentsService = _FakeMerchantReceivedPaymentsService();
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: service,
          merchantReceivedPaymentsService: receivedPaymentsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(receivedPaymentsService.calls, 2);
  });

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
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: incompleteProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
        ),
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
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: longProfile,
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
        ),
      ),
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
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
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
          merchantBalanceService: _FakeMerchantBalanceService(),
          merchantReceivedPaymentsService:
              _FakeMerchantReceivedPaymentsService(),
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
    final balanceService = _FakeMerchantBalanceService();
    final receivedPaymentsService = _FakeMerchantReceivedPaymentsService();
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: balanceService,
          merchantReceivedPaymentsService: receivedPaymentsService,
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
    expect(balanceService.calls, 2);
    expect(receivedPaymentsService.calls, 2);
    final details = tester.widget<Text>(
      find.byKey(const Key('merchantDashboardBusinessDetails')),
    );
    expect(details.data, contains('Central Canteen Updated'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create tab returns to Dashboard selection after route closes', (
    tester,
  ) async {
    final balanceService = _FakeMerchantBalanceService();
    final receivedPaymentsService = _FakeMerchantReceivedPaymentsService();
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          profile: _merchantProfile,
          merchantBalanceService: balanceService,
          merchantReceivedPaymentsService: receivedPaymentsService,
          paymentIntentService: _FakePaymentIntentService(),
        ),
      ),
    );

    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();
    expect(find.text('Create Payment Request'), findsOneWidget);
    expect(balanceService.calls, 1);
    expect(receivedPaymentsService.calls, 1);

    Navigator.of(tester.element(find.text('Create Payment Request'))).pop();
    await tester.pumpAndSettle();
    expect(balanceService.calls, 2);
    expect(receivedPaymentsService.calls, 2);

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.currentIndex, 0);
  });

  testWidgets(
    'confirmed payment refreshes dashboard once and returns to Dashboard',
    (tester) async {
      final createdAt = DateTime.now();
      final pending = MerchantPaymentIntent(
        paymentReference: 'merchant-ref-123',
        merchantName: 'Central Canteen',
        amountMinor: 1000,
        currency: 'LKR',
        status: 'PENDING',
        createdAt: createdAt,
        expiresAt: createdAt.add(const Duration(minutes: 15)),
      );
      final success = MerchantPaymentIntent(
        paymentReference: pending.paymentReference,
        merchantName: pending.merchantName,
        amountMinor: pending.amountMinor,
        currency: pending.currency,
        status: 'SUCCESS',
        createdAt: pending.createdAt,
        expiresAt: pending.expiresAt,
      );
      final paymentService = _FakePaymentIntentService(
        createdIntent: pending,
        statusResponses: [success],
      );
      final balanceService = _FakeMerchantBalanceService();
      final receivedPaymentsService = _FakeMerchantReceivedPaymentsService();

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: _merchantProfile,
            paymentIntentService: paymentService,
            merchantBalanceService: balanceService,
            merchantReceivedPaymentsService: receivedPaymentsService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(balanceService.calls, 1);
      expect(receivedPaymentsService.calls, 1);

      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(find.text('Request a payment'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('paymentAmountField')),
        '10.00',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('createPaymentRequestButton')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('createPaymentRequestButton')));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      expect(find.text('Payment received'), findsOneWidget);
      expect(paymentService.statusCalls, 1);
      expect(balanceService.calls, 2);
      expect(receivedPaymentsService.calls, 2);

      await tester.scrollUntilVisible(
        find.text('Done'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Create Payment Request'))).pop();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(balanceService.calls, 2);
      expect(receivedPaymentsService.calls, 2);
    },
  );

  testWidgets(
    'Profile bottom tab replaces Terminal and displays merchant profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: _merchantProfile,
            merchantBalanceService: _FakeMerchantBalanceService(),
            merchantReceivedPaymentsService:
                _FakeMerchantReceivedPaymentsService(),
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
