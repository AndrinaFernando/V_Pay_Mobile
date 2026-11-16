import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/topup/screens/topup_history_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class HistoryService implements TopUpService {
  List<TopUp> items = [];
  Object? error;
  int listCalls = 0;

  @override
  Future<List<TopUp>> list() async {
    listCalls++;
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();

  @override
  Future<TopUp> get(String id) => throw UnimplementedError();
}

void main() {
  testWidgets('unknown start hides technical details and advises support', (
    tester,
  ) async {
    final service = HistoryService()
      ..items = [
        const TopUp(
          id: 'unknown',
          status: 'START_UNKNOWN',
          requestedAmount: 50,
          message: 'Internal debug details',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: TopUpHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkout status unknown'));
    await tester.pumpAndSettle();
    expect(find.text('Internal debug details'), findsNothing);
    expect(
      find.text(
        'We couldn’t confirm if this top-up started. Please contact support before trying again.',
      ),
      findsOneWidget,
    );
  });
  final labels = {
    'FAILED': 'Payment declined',
    'TIMEOUT': 'Payment timed out',
    'CANCELLED': 'Payment cancelled',
    'PENDING': 'Waiting for payment confirmation',
    'START_FAILED': 'Checkout could not start',
    'START_UNKNOWN': 'Checkout status unknown',
  };

  for (final entry in labels.entries) {
    testWidgets('history displays ${entry.key}', (tester) async {
      final service = HistoryService()
        ..items = [TopUp(id: 'ref1', status: entry.key, requestedAmount: 100)];
      await tester.pumpWidget(
        MaterialApp(home: TopUpHistoryScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets(
    'success details show requested amount, final amount and reference',
    (tester) async {
      final service = HistoryService()
        ..items = [
          const TopUp(
            id: 'ref123',
            status: 'SUCCESS',
            requestedAmount: 100,
            amount: 120,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(home: TopUpHistoryScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Top-up successful'), findsOneWidget);
      expect(find.text('Rs. 120'), findsOneWidget);
      await tester.tap(find.text('Top-up successful'));
      await tester.pumpAndSettle();
      expect(find.text('Requested: Rs. 100'), findsOneWidget);
      expect(find.text('Final amount: Rs. 120'), findsOneWidget);
      expect(find.text('Reference: ref123'), findsWidgets);
    },
  );

  testWidgets('empty history shows its empty state', (tester) async {
    final service = HistoryService();
    await tester.pumpWidget(
      MaterialApp(home: TopUpHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No top-ups yet.'), findsOneWidget);
  });

  testWidgets('history error offers retry and reloads', (tester) async {
    final service = HistoryService()..error = Exception('offline');
    await tester.pumpWidget(
      MaterialApp(home: TopUpHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load top-up history.'), findsOneWidget);
    service.error = null;
    service.items = [
      const TopUp(id: 'retry', status: 'SUCCESS', requestedAmount: 50),
    ];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(service.listCalls, 2);
    expect(find.text('Top-up successful'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads a populated history', (tester) async {
    final service = HistoryService()
      ..items = [
        const TopUp(id: 'old', status: 'PENDING', requestedAmount: 50),
      ];
    await tester.pumpWidget(
      MaterialApp(home: TopUpHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    service.items = [
      const TopUp(id: 'new', status: 'SUCCESS', requestedAmount: 75),
    ];
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(service.listCalls, 2);
    expect(find.text('Top-up successful'), findsOneWidget);
    expect(find.text('Reference: new'), findsOneWidget);
  });
}
