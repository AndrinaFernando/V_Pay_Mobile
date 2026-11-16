import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vpay_mobile/core/network/api_client.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/customer/models/customer_transaction.dart';
import 'package:vpay_mobile/features/customer/screens/customer_activity_screen.dart';
import 'package:vpay_mobile/features/customer/services/customer_activity_service.dart';
import 'package:vpay_mobile/features/customer/services/customer_transaction_service.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.response) : super(authService: _FakeAuthService());

  final http.Response response;
  String? requestedPath;

  @override
  Future<http.Response> authenticatedGet(String path) async {
    requestedPath = path;
    return response;
  }
}

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CustomerTransaction _transaction({
  required String id,
  required String merchant,
  required DateTime createdAt,
}) {
  return CustomerTransaction(
    transactionId: id,
    paymentReference: 'payment-$id',
    merchantName: merchant,
    amountMinor: 1250,
    currency: 'LKR',
    status: CustomerPaymentStatus.success,
    createdAt: createdAt,
  );
}

void main() {
  for (final missingPayments in [true, false]) {
    testWidgets(
      'partial activity shows available records and a warning (${missingPayments ? 'QR' : 'top-ups'} unavailable)',
      (tester) async {
        final records = CustomerActivityList(
          [
            if (missingPayments)
              CustomerTransaction.fromTopUp(
                const TopUp(
                  id: 'topup-1',
                  status: 'SUCCESS',
                  requestedAmount: 50,
                  amount: 50,
                ),
              )
            else
              _transaction(
                id: 'qr-1',
                merchant: 'ABC Store',
                createdAt: DateTime.utc(2026, 11, 15),
              ),
          ],
          paymentsUnavailable: missingPayments,
          topUpsUnavailable: !missingPayments,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomerActivityScreen(
                transactionsFuture: Future.value(records),
                onRefresh: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('customerActivityIncompleteNotice')),
          findsOneWidget,
        );
        expect(find.textContaining('may be incomplete'), findsOneWidget);
        expect(
          find.text(missingPayments ? 'Rupio Top-up' : 'ABC Store'),
          findsOneWidget,
        );
      },
    );
  }
  test('authenticated history service parses and sorts newest first', () async {
    final client = _FakeApiClient(
      http.Response(
        '{"success":true,"data":{"transactions":['
        '{"transactionId":"older","paymentReference":"pay-old","merchantName":"Older Shop","amountMinor":1000,"currency":"LKR","status":"SUCCESS","createdAt":"2026-11-14T08:00:00.000Z"},'
        '{"transactionId":"newer","paymentReference":"pay-new","merchantName":"New Shop","amountMinor":2500,"currency":"LKR","status":"SUCCESS","createdAt":"2026-11-15T08:00:00.000Z"}'
        ']}}',
        200,
      ),
    );

    final transactions = await ApiCustomerTransactionService(apiClient: client)
        .getTransactions(limit: 10);

    expect(client.requestedPath, '/api/customer/transactions?limit=10');
    expect(transactions.map((item) => item.transactionId), ['newer', 'older']);
  });

  testWidgets('activity renders transactions, empty data, and errors', (
    tester,
  ) async {
    final transactions = [
      _transaction(
        id: 'newer',
        merchant: 'Colombo Cafe',
        createdAt: DateTime.utc(2026, 11, 15, 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerActivityScreen(
            transactionsFuture: Future.value(transactions),
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Colombo Cafe'), findsOneWidget);
    expect(find.text('-Rs. 12.50'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerActivityScreen(
            transactionsFuture: Future.value(const []),
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No payment activity yet'), findsOneWidget);

    final errorCompleter = Completer<List<CustomerTransaction>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerActivityScreen(
            transactionsFuture: errorCompleter.future,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    errorCompleter.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load activity'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retryCustomerActivityButton')),
      findsOneWidget,
    );
  });

  testWidgets('activity retry invokes the supplied refresh callback', (
    tester,
  ) async {
    var refreshes = 0;
    Future<void> refresh() async {
      refreshes++;
    }

    final failure = Completer<List<CustomerTransaction>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerActivityScreen(
            transactionsFuture: failure.future,
            onRefresh: refresh,
          ),
        ),
      ),
    );
    failure.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('retryCustomerActivityButton')));
    await tester.pump();
    expect(refreshes, 1);
  });
}
