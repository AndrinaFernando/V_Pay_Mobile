import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/topup/screens/topup_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class FakeTopUpService implements TopUpService {
  int? createdAmount;
  TopUp current = const TopUp(
    id: 'topup1',
    status: 'PENDING',
    requestedAmount: 100,
    checkoutUrl: 'https://rupio.example/checkout',
  );
  @override
  Future<TopUp> create(int amount) async {
    createdAmount = amount;
    return current;
  }

  @override
  Future<TopUp> get(String id) async => current;
  @override
  Future<List<TopUp>> list() async => [];
}

void main() {
  testWidgets('starts checkout and shows only backend-confirmed result', (
    tester,
  ) async {
    final service = FakeTopUpService();
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: TopUpScreen(
          service: service,
          openCheckout: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pump();
    expect(service.createdAmount, 100);
    expect(opened.toString(), 'https://rupio.example/checkout');
    expect(find.text('Waiting for payment confirmation'), findsWidgets);
    expect(find.text('Top-up successful'), findsNothing);
    service.current = const TopUp(
      id: 'topup1',
      status: 'SUCCESS',
      requestedAmount: 100,
      amount: 120,
      message: 'Approved',
    );
    await tester.tap(find.text('Check status'));
    await tester.pump();
    expect(find.text('Top-up successful'), findsWidgets);
    expect(find.text('Final amount: Rs. 120'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rejects an invalid amount without starting checkout', (
    tester,
  ) async {
    final service = FakeTopUpService();
    await tester.pumpWidget(MaterialApp(home: TopUpScreen(service: service)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pump();
    expect(service.createdAmount, isNull);
    expect(
      find.text('Enter a whole amount from Rs. 1 to Rs. 1,000,000.'),
      findsOneWidget,
    );
  });
}
