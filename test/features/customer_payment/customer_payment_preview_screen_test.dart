import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_payment_preview_screen.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_preview_service.dart';

typedef _PreviewResponse = Future<CustomerPaymentPreview> Function();

class _FakePreviewService implements CustomerPaymentPreviewService {
  _FakePreviewService(List<_PreviewResponse> responses)
    : _responses = List.of(responses);

  final List<_PreviewResponse> _responses;
  final references = <String>[];

  @override
  Future<CustomerPaymentPreview> getPreview(String paymentReference) {
    references.add(paymentReference);
    return _responses.removeAt(0)();
  }
}

CustomerPaymentPreview _preview({
  CustomerPaymentStatus status = CustomerPaymentStatus.pending,
  DateTime? expiresAt,
  String? description = 'Lunch order',
}) {
  return CustomerPaymentPreview(
    paymentReference: 'payment-ref-123',
    merchantName: 'Colombo Cafe',
    amountMinor: 1285050,
    currency: 'LKR',
    status: status,
    createdAt: DateTime.utc(2099, 2, 3, 8),
    expiresAt: expiresAt ?? DateTime.utc(2099, 2, 3, 8, 15),
    description: description,
  );
}

Future<void> _pumpPreview(
  WidgetTester tester,
  CustomerPaymentPreviewService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CustomerPaymentPreviewScreen(
        paymentReference: 'payment-ref-123',
        previewService: service,
      ),
    ),
  );
}

void main() {
  test('formats LKR minor units without an extra dependency', () {
    expect(formatLkrMinor(0), 'Rs. 0.00');
    expect(formatLkrMinor(105), 'Rs. 1.05');
    expect(formatLkrMinor(1285050), 'Rs. 12,850.50');
  });

  test('rejects incomplete or unsupported preview data', () {
    final validJson = <String, dynamic>{
      'paymentReference': 'payment-ref-123',
      'merchantName': 'Colombo Cafe',
      'amountMinor': 2500,
      'currency': 'LKR',
      'status': 'PENDING',
      'createdAt': '2099-02-03T08:00:00Z',
      'expiresAt': '2099-02-03T08:15:00Z',
    };

    expect(
      () => CustomerPaymentPreview.fromJson(
        {...validJson}..remove('amountMinor'),
      ),
      throwsFormatException,
    );
    expect(
      () => CustomerPaymentPreview.fromJson({...validJson, 'currency': 'USD'}),
      throwsFormatException,
    );
  });

  testWidgets('shows loading then backend-provided preview details', (
    tester,
  ) async {
    final completer = Completer<CustomerPaymentPreview>();
    final service = _FakePreviewService([() => completer.future]);

    await _pumpPreview(tester, service);
    expect(find.byKey(const ValueKey('paymentPreviewLoading')), findsOneWidget);

    completer.complete(_preview());
    await tester.pumpAndSettle();

    expect(find.text('Colombo Cafe'), findsOneWidget);
    expect(find.text('Rs. 12,850.50'), findsOneWidget);
    expect(find.text('payment-ref-123'), findsOneWidget);
    expect(find.text('Lunch order'), findsOneWidget);
    expect(find.text('PENDING'), findsAtLeastNWidgets(1));
    expect(find.textContaining('2099-02-03'), findsOneWidget);
    expect(find.text('Payment confirmation unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Payment confirmation unavailable'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(service.references, ['payment-ref-123']);
  });

  testWidgets('retries a failed read-only lookup safely', (tester) async {
    final service = _FakePreviewService([
      () => Future.error(
        const CustomerPaymentPreviewException(
          CustomerPaymentPreviewFailure.network,
        ),
      ),
      () async => _preview(),
    ]);

    await _pumpPreview(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('No network connection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retryPaymentPreviewButton')));
    await tester.pumpAndSettle();

    expect(find.text('Colombo Cafe'), findsOneWidget);
    expect(service.references, ['payment-ref-123', 'payment-ref-123']);
  });

  final failureCases = <CustomerPaymentPreviewFailure, String>{
    CustomerPaymentPreviewFailure.unknownReference: 'Payment not found',
    CustomerPaymentPreviewFailure.expired: 'Payment expired',
    CustomerPaymentPreviewFailure.alreadyUsed: 'Payment already used',
    CustomerPaymentPreviewFailure.authentication: 'Session verification failed',
    CustomerPaymentPreviewFailure.network: 'No network connection',
    CustomerPaymentPreviewFailure.timeout: 'Request timed out',
    CustomerPaymentPreviewFailure.invalidResponse: 'Invalid payment response',
    CustomerPaymentPreviewFailure.unavailable: 'Payment service unavailable',
  };

  for (final entry in failureCases.entries) {
    testWidgets('shows the ${entry.key.name} lookup error', (tester) async {
      final service = _FakePreviewService([
        () => Future.error(CustomerPaymentPreviewException(entry.key)),
      ]);

      await _pumpPreview(tester, service);
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.byKey(const ValueKey('retryPaymentPreviewButton')),
        findsOneWidget,
      );
    });
  }

  testWidgets('handles expired and already-completed preview data', (
    tester,
  ) async {
    var service = _FakePreviewService([
      () async => _preview(expiresAt: DateTime.utc(2020), description: null),
    ]);
    await _pumpPreview(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('EXPIRED'), findsAtLeastNWidgets(1));
    expect(find.textContaining('has expired'), findsOneWidget);
    expect(find.text('Lunch order'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service = _FakePreviewService([
      () async => _preview(
        status: CustomerPaymentStatus.success,
        expiresAt: DateTime.utc(2020),
      ),
    ]);
    await _pumpPreview(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('SUCCESS'), findsAtLeastNWidgets(1));
    expect(find.textContaining('already been completed'), findsOneWidget);
  });

  testWidgets('preview layout fits a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakePreviewService([() async => _preview()]);
    await _pumpPreview(tester, service);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paymentPreviewDetails')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
