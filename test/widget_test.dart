import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/card/models/vpay_card.dart';
import 'package:vpay_mobile/features/card/services/card_api_service.dart';
import 'package:vpay_mobile/features/customer/screens/customer_home_screen.dart';

const _profile = VPayUserProfile(
  uid: 'customer-uid',
  name: 'Kasun Perera',
  email: 'kasun@example.com',
  role: 'CUSTOMER',
  status: 'ACTIVE',
);

final _card = VPayCard.fromJson({
  'id': 'customer-uid',
  'maskedNumber': '•••• •••• •••• 4827',
  'balance': 12850,
  'status': 'FROZEN',
  'expiresAt': '2029-09-01T00:00:00.000Z',
  'createdAt': '2026-09-01T00:00:00.000Z',
});

class _FakeCardApiService extends CardApiService {
  _FakeCardApiService({this.failFirst = false});

  final bool failFirst;
  int requests = 0;

  @override
  Future<VPayCard> getCurrentUserCard() async {
    requests++;
    if (failFirst && requests == 1) {
      throw const ApiException(404, 'VPay virtual card not found');
    }
    return _card;
  }
}

void main() {
  test('card model accepts numeric JSON and parses ISO dates safely', () {
    expect(_card.balance, 12850);
    expect(_card.expiresAt, DateTime.utc(2029, 9, 1));

    final cardWithDouble = VPayCard.fromJson({
      'id': 'customer-uid',
      'maskedNumber': null,
      'balance': 12.5,
      'status': 'ACTIVE',
      'expiresAt': 'invalid',
      'createdAt': null,
    });
    expect(cardWithDouble.balance, 12.5);
    expect(cardWithDouble.expiresAt, isNull);
    expect(cardWithDouble.createdAt, isNull);
  });

  testWidgets('Customer Home uses live card data on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeCardApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerHomeScreen(profile: _profile, cardApiService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.requests, 1);
    expect(find.textContaining('Kasun'), findsOneWidget);
    expect(find.text('Rs. 12,850.00'), findsOneWidget);
    expect(find.text('•••• •••• •••• 4827'), findsOneWidget);
    expect(find.text('KASUN PERERA'), findsOneWidget);
    expect(find.text('09/29'), findsOneWidget);
    expect(find.text('FROZEN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing card shows an error and Retry fetches again', (
    tester,
  ) async {
    final service = _FakeCardApiService(failFirst: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerHomeScreen(profile: _profile, cardApiService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your VPay virtual card could not be found.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.requests, 2);
    expect(find.text('Rs. 12,850.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
