import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/topup/screens/topup_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class FakeTopUpService implements TopUpService {
  int? createdAmount;
  int createCalls = 0;
  List<TopUp> history = [];
  TopUp current = const TopUp(
    id: 'topup1',
    status: 'PENDING',
    requestedAmount: 100,
    checkoutUrl: 'https://rupio.example/checkout',
  );
  @override
  Future<TopUp> create(int amount) async {
    createCalls++;
    createdAmount = amount;
    return current;
  }

  @override
  Future<TopUp> get(String id) async => current;
  @override
  Future<List<TopUp>> list() async => history;
}

class DelayedTopUpService extends FakeTopUpService {
  final pending = Completer<TopUp>();
  @override
  Future<TopUp> create(int amount) {
    createCalls++;
    return pending.future;
  }
}

void main() {
  testWidgets('loading prevents duplicate checkout and resets on failure', (
    tester,
  ) async {
    final service = DelayedTopUpService();
    await tester.pumpWidget(MaterialApp(home: TopUpScreen(service: service)));
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pump();
    expect(find.text('Starting checkout...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(service.createCalls, 1);
    service.pending.completeError(Exception('Offline'));
    await tester.pump();
    expect(find.text('Continue to Rupio'), findsOneWidget);
    expect(
      find.text(
        'We couldn’t confirm if your top-up started. Check Top-up history before trying again.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('hides technical checkout errors and directs user to history', (
    tester,
  ) async {
    final service = DelayedTopUpService();
    await tester.pumpWidget(MaterialApp(home: TopUpScreen(service: service)));
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Continue to Rupio'));
    await tester.pump();
    service.pending.completeError(
      const ApiException(
        503,
        'Rupio staging is not configured on the backend.',
      ),
    );
    await tester.pump();
    expect(
      find.text('Rupio staging is not configured on the backend.'),
      findsNothing,
    );
    expect(
      find.text(
        'We couldn’t confirm if your top-up started. Check Top-up history before trying again.',
      ),
      findsOneWidget,
    );
  });
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
                            if (context.mounted) {
                              Navigator.of(context).pop(confirmed);
                            }
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

  testWidgets(
    'pending history reopens the original checkout without creating a top-up',
    (tester) async {
      final service = FakeTopUpService()
        ..history = [
          const TopUp(
            id: 'existing_topup',
            status: 'PENDING',
            requestedAmount: 100,
            checkoutUrl: 'https://rupio.example/checkout/existing',
          ),
        ];
      Uri? openedUrl;
      String? openedId;
      await tester.pumpWidget(
        MaterialApp(
          home: TopUpScreen(
            service: service,
            checkoutBuilder: (uri, id, api) {
              openedUrl = uri;
              openedId = id;
              return Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Leave resumed checkout'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Top-up history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waiting for payment confirmation'));
      await tester.pumpAndSettle();
      expect(find.text('Open checkout'), findsOneWidget);
      await tester.tap(find.text('Open checkout'));
      await tester.pumpAndSettle();
      expect(openedId, 'existing_topup');
      expect(openedUrl, Uri.parse('https://rupio.example/checkout/existing'));
      expect(service.createCalls, 0);
      await tester.tap(find.text('Leave resumed checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Payment cancelled'), findsNothing);
      expect(service.history.single.status, 'PENDING');
      await tester.tap(find.text('Top-up history'));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for payment confirmation'), findsOneWidget);
      expect(find.text('Payment cancelled'), findsNothing);
      expect(service.createCalls, 0);
    },
  );

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
    expect(find.text('Invalid amount'), findsOneWidget);
  });
}
