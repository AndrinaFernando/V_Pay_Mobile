import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/topup/screens/topup_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class FakeTopUpService implements TopUpService {
  int? createdAmount;
  List<TopUp> history = [];
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
  Future<List<TopUp>> list() async => history;
}

void main() {
  testWidgets('history opens on a separate screen and shows details', (
    tester,
  ) async {
    final service = FakeTopUpService()
      ..history = [
        const TopUp(
          id: 'history1',
          status: 'SUCCESS',
          requestedAmount: 50,
          amount: 50,
        ),
      ];
    await tester.pumpWidget(MaterialApp(home: TopUpScreen(service: service)));
    expect(find.text('Top-up successful'), findsNothing);
    await tester.tap(find.text('Top-up history'));
    await tester.pumpAndSettle();
    expect(find.text('Top-up successful'), findsOneWidget);
    await tester.tap(find.text('Top-up successful'));
    await tester.pumpAndSettle();
    expect(find.text('Reference: history1'), findsWidgets);
  });
  testWidgets('returns to home with the backend-confirmed checkout result', (
    tester,
  ) async {
    final service = FakeTopUpService();
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => TopUpScreen(
                      service: service,
                      checkoutBuilder: (url, id, api) => Scaffold(
                        body: TextButton(
                          onPressed: () async {
                            final confirmed = await api.get(id);
                            if (context.mounted)
                              Navigator.of(context).pop(confirmed);
                          },
                          child: const Text('Confirm result'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm result'), findsOneWidget);
    service.current = const TopUp(
      id: 'topup1',
      status: 'SUCCESS',
      requestedAmount: 100,
      amount: 100,
    );
    await tester.tap(find.text('Confirm result'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(result, 'Top-up successful');
  });
  testWidgets('leaving checkout restores the amount screen and keeps history', (
    tester,
  ) async {
    final service = FakeTopUpService();
    service.history = [service.current];
    await tester.pumpWidget(
      MaterialApp(
        home: TopUpScreen(
          service: service,
          checkoutBuilder: (uri, id, api) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Leave checkout'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pumpAndSettle();
    expect(service.createdAmount, 100);
    expect(find.text('Leave checkout'), findsOneWidget);
    await tester.tap(find.text('Leave checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for payment confirmation'), findsNothing);
    expect(find.text('Continue to Rupio'), findsOneWidget);
    await tester.tap(find.text('Top-up history'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for payment confirmation'), findsOneWidget);
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
