import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/merchant/models/payment_amount_limits.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_payment_intent.dart';
import 'package:vpay_mobile/features/merchant/screens/create_payment_request_screen.dart';
import 'package:vpay_mobile/features/merchant/screens/payment_intent_qr_screen.dart';
import 'package:vpay_mobile/features/merchant/services/payment_intent_service.dart';

MerchantPaymentIntent _intent({
  String paymentReference = 'server-reference-abc123',
  int amountMinor = 1235,
  String currency = 'LKR',
  String status = 'PENDING',
  String? description,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final created = createdAt ?? DateTime.now();
  return MerchantPaymentIntent(
    paymentReference: paymentReference,
    merchantName: 'Central Canteen',
    amountMinor: amountMinor,
    currency: currency,
    status: status,
    createdAt: created,
    expiresAt: expiresAt ?? created.add(const Duration(minutes: 15)),
    description: description,
  );
}

class _FakePaymentIntentService implements PaymentIntentService {
  _FakePaymentIntentService({
    this.intent,
    this.error,
    this.pending,
    this.statusResponses,
    this.statusOutcomes,
  });

  final MerchantPaymentIntent? intent;
  final Object? error;
  final Completer<MerchantPaymentIntent>? pending;
  final List<MerchantPaymentIntent>? statusResponses;
  final List<Object>? statusOutcomes;
  int calls = 0;
  int statusCalls = 0;
  int? requestedAmountMinor;
  String? requestedDescription;

  @override
  Future<MerchantPaymentIntent> createPaymentIntent({
    required int amountMinor,
    String? description,
  }) {
    calls++;
    requestedAmountMinor = amountMinor;
    requestedDescription = description;
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value(intent);
  }

  @override
  Future<MerchantPaymentIntent> getPaymentIntent({
    required String paymentReference,
  }) async {
    final outcomes = statusOutcomes;
    if (outcomes != null && outcomes.isNotEmpty) {
      final outcome = outcomes[statusCalls.clamp(0, outcomes.length - 1)];
      statusCalls++;
      if (outcome is MerchantPaymentIntent) return outcome;
      throw outcome;
    }
    if (error != null) throw error!;
    final responses = statusResponses;
    final response = responses == null || responses.isEmpty
        ? intent
        : responses[statusCalls.clamp(0, responses.length - 1)];
    statusCalls++;
    return response!;
  }

  @override
  Future<List<MerchantPaymentIntent>> listPaymentIntents({
    int limit = 20,
  }) async => const [];
}

Future<void> _showForm(
  WidgetTester tester,
  _FakePaymentIntentService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CreatePaymentRequestScreen(paymentIntentService: service),
    ),
  );
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final button = find.byKey(const Key('createPaymentRequestButton'));
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
}

Future<void> _scrollToError(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('paymentRequestError')),
    -100,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  test('converts LKR amounts to minor units without floating point math', () {
    expect(parseLkrAmountToMinorUnits('1'), 100);
    expect(parseLkrAmountToMinorUnits('12.5'), 1250);
    expect(parseLkrAmountToMinorUnits('12.35'), 1235);
    expect(parseLkrAmountToMinorUnits('0.01'), 1);
    expect(parseLkrAmountToMinorUnits('0'), 0);
    expect(parseLkrAmountToMinorUnits('12.345'), isNull);
    expect(parseLkrAmountToMinorUnits('1.234'), isNull);
    expect(parseLkrAmountToMinorUnits('1.'), isNull);
    expect(parseLkrAmountToMinorUnits('1,000'), isNull);
  });

  test('default merchant amount policy covers LKR 10 through LKR 100,000', () {
    const limits = PaymentAmountLimits.lkrDefault;
    expect(limits.accepts(parseLkrAmountToMinorUnits('10.00')!), isTrue);
    expect(limits.accepts(parseLkrAmountToMinorUnits('100000.00')!), isTrue);
    expect(limits.accepts(parseLkrAmountToMinorUnits('9.99')!), isFalse);
    expect(limits.accepts(parseLkrAmountToMinorUnits('100000.01')!), isFalse);
    expect(limits.displayRange, 'LKR 10.00–LKR 100,000.00');
  });

  testWidgets('valid request posts minor units and navigates to its QR', (
    tester,
  ) async {
    final service = _FakePaymentIntentService(
      intent: _intent(description: 'Lunch order'),
    );
    await _showForm(tester, service);

    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '12.35',
    );
    await tester.enterText(
      find.byKey(const Key('paymentDescriptionField')),
      'Lunch order',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(service.requestedAmountMinor, 1235);
    expect(service.requestedDescription, 'Lunch order');
    expect(find.byType(PaymentIntentQrScreen), findsOneWidget);
    expect(find.byKey(const Key('paymentIntentQrCode')), findsOneWidget);
    expect(find.text('LKR 12.35'), findsOneWidget);
    expect(find.text('Lunch order'), findsOneWidget);
    final qr = tester.widget<QrImageView>(
      find.byKey(const Key('paymentIntentQrCode')),
    );
    expect(_intent().qrPayload, 'server-reference-abc123');
    expect(qr.backgroundColor, Colors.white);
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.Q);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejects out-of-range and over-precision amounts before API call',
    (tester) async {
      final service = _FakePaymentIntentService(intent: _intent());
      await _showForm(tester, service);

      await tester.enterText(
        find.byKey(const Key('paymentAmountField')),
        '9.99',
      );
      await _tapSubmit(tester);
      await tester.pump();
      expect(
        find.text('Enter an amount within LKR 10.00–LKR 100,000.00.'),
        findsOneWidget,
      );
      expect(service.calls, 0);

      await tester.enterText(find.byKey(const Key('paymentAmountField')), '0');
      await _tapSubmit(tester);
      await tester.pump();
      expect(
        find.text('Enter an amount within LKR 10.00–LKR 100,000.00.'),
        findsOneWidget,
      );
      expect(service.calls, 0);

      await tester.enterText(
        find.byKey(const Key('paymentAmountField')),
        '100000.01',
      );
      await _tapSubmit(tester);
      await tester.pump();
      expect(
        find.text('Enter an amount within LKR 10.00–LKR 100,000.00.'),
        findsOneWidget,
      );
      expect(service.calls, 0);

      await tester.enterText(
        find.byKey(const Key('paymentAmountField')),
        '10.001',
      );
      await _tapSubmit(tester);
      await tester.pump();
      expect(
        find.text('Enter a valid amount with up to two decimal places.'),
        findsOneWidget,
      );
      expect(service.calls, 0);
      expect(find.byType(PaymentIntentQrScreen), findsNothing);
    },
  );

  testWidgets('rejects negative amounts before calling the API', (
    tester,
  ) async {
    final service = _FakePaymentIntentService(intent: _intent());
    await _showForm(tester, service);

    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '-12.50',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(
      find.text('Enter an amount within LKR 10.00–LKR 100,000.00.'),
      findsOneWidget,
    );
    expect(service.calls, 0);
    expect(find.byType(PaymentIntentQrScreen), findsNothing);
  });

  testWidgets('shows loading and ignores duplicate submission taps', (
    tester,
  ) async {
    final pending = Completer<MerchantPaymentIntent>();
    final service = _FakePaymentIntentService(pending: pending);
    await _showForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '10.00',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(service.calls, 1);
    expect(
      find.byKey(const Key('paymentRequestLoadingIndicator')),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('createPaymentRequestButton')),
    );
    expect(button.onPressed, isNull);

    pending.complete(_intent(amountMinor: 1000));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentIntentQrScreen), findsOneWidget);
  });

  testWidgets('shows backend errors and stays on the form', (tester) async {
    final service = _FakePaymentIntentService(
      error: const ApiException(400, 'Amount must be greater than zero'),
    );
    await _showForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '10.00',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    await _scrollToError(tester);

    expect(find.text('Amount must be greater than zero'), findsOneWidget);
    expect(find.byType(PaymentIntentQrScreen), findsNothing);
  });

  testWidgets('does not navigate when the returned intent is invalid', (
    tester,
  ) async {
    final service = _FakePaymentIntentService(
      intent: _intent(amountMinor: 1000, status: 'COMPLETED'),
    );
    await _showForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('paymentAmountField')),
      '10.00',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    await _scrollToError(tester);

    expect(
      find.text(
        'The server returned an invalid payment request. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(PaymentIntentQrScreen), findsNothing);
  });

  testWidgets('creates a new request only after backend reports expiry', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 14, 10);
    final pendingIntent = _intent(
      amountMinor: 500,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 2)),
    );
    final expiredIntent = _intent(
      amountMinor: 500,
      status: 'EXPIRED',
      createdAt: now,
      expiresAt: pendingIntent.expiresAt,
    );
    final service = _FakePaymentIntentService(
      intent: pendingIntent,
      statusResponses: [pendingIntent, expiredIntent],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => PaymentIntentQrScreen(
                      paymentIntent: pendingIntent,
                      paymentIntentService: service,
                      statusPollInterval: const Duration(hours: 1),
                      clock: () => now,
                    ),
                  ),
                );
              },
              child: const Text('Open request'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open request'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('paymentIntentQrCode')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('paymentExpiryCard')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('00:02'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Request expired'), findsWidgets);
    expect(find.byKey(const Key('paymentIntentQrCode')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('createNewPaymentRequestButton')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('createNewPaymentRequestButton')),
      findsOneWidget,
    );
    expect(service.statusCalls, 2);

    await tester.tap(find.byKey(const Key('createNewPaymentRequestButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open request'), findsOneWidget);
  });

  testWidgets('only displays success after the backend confirms it', (
    tester,
  ) async {
    final pendingIntent = _intent();
    final completedIntent = _intent(
      status: 'SUCCESS',
      createdAt: pendingIntent.createdAt,
      expiresAt: pendingIntent.expiresAt,
    );
    final service = _FakePaymentIntentService(
      intent: pendingIntent,
      statusResponses: [completedIntent],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: pendingIntent,
          paymentIntentService: service,
          statusPollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Payment received'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('paymentCreatedAt')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('paymentCreatedAt')), findsOneWidget);
    expect(find.byKey(const Key('paymentIntentQrCode')), findsNothing);
    expect(service.statusCalls, 1);
  });

  testWidgets('PENDING to SUCCESS refreshes merchant data exactly once', (
    tester,
  ) async {
    final pendingIntent = _intent();
    final successIntent = _intent(
      status: 'SUCCESS',
      createdAt: pendingIntent.createdAt,
      expiresAt: pendingIntent.expiresAt,
    );
    final service = _FakePaymentIntentService(statusOutcomes: [successIntent]);
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: pendingIntent,
          paymentIntentService: service,
          onConfirmedSuccess: () async {
            refreshCalls++;
          },
          statusPollInterval: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Payment received'), findsOneWidget);
    expect(refreshCalls, 1);
    expect(service.statusCalls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(refreshCalls, 1);
    expect(service.statusCalls, 1);
  });

  testWidgets('PROCESSING continues polling until SUCCESS', (tester) async {
    final pendingIntent = _intent();
    final processingIntent = _intent(
      status: 'PROCESSING',
      createdAt: pendingIntent.createdAt,
      expiresAt: pendingIntent.expiresAt,
    );
    final successIntent = _intent(
      status: 'SUCCESS',
      createdAt: pendingIntent.createdAt,
      expiresAt: pendingIntent.expiresAt,
    );
    final service = _FakePaymentIntentService(
      statusOutcomes: [processingIntent, successIntent],
    );
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: pendingIntent,
          paymentIntentService: service,
          onConfirmedSuccess: () async {
            refreshCalls++;
          },
          statusPollInterval: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Payment processing'), findsOneWidget);
    expect(service.statusCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('Payment received'), findsOneWidget);
    expect(service.statusCalls, 2);
    expect(refreshCalls, 1);
  });

  testWidgets('renders each agreed payment status from the backend', (
    tester,
  ) async {
    const cases = <String, String>{
      'PENDING': 'Awaiting customer payment',
      'PROCESSING': 'Payment processing',
      'SUCCESS': 'Payment received',
      'FAILED': 'Payment failed',
      'EXPIRED': 'Request expired',
    };

    for (final entry in cases.entries) {
      final pendingIntent = _intent();
      final serverIntent = _intent(
        status: entry.key,
        createdAt: pendingIntent.createdAt,
        expiresAt: pendingIntent.expiresAt,
      );
      final service = _FakePaymentIntentService(
        intent: serverIntent,
        statusResponses: [serverIntent],
      );
      var refreshCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentIntentQrScreen(
            paymentIntent: pendingIntent,
            paymentIntentService: service,
            onConfirmedSuccess: () async {
              refreshCalls++;
            },
            statusPollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(entry.value),
        entry.key == 'EXPIRED' ? findsWidgets : findsOneWidget,
        reason: entry.key,
      );
      expect(
        find.byType(RefreshIndicator),
        entry.key == 'PENDING' || entry.key == 'PROCESSING'
            ? findsOneWidget
            : findsNothing,
        reason: 'Only active requests can be manually refreshed',
      );
      expect(service.statusCalls, 1, reason: entry.key);
      expect(
        refreshCalls,
        entry.key == 'SUCCESS' ? 1 : 0,
        reason: 'Only backend-confirmed success refreshes merchant data',
      );
      if (entry.key == 'FAILED' || entry.key == 'EXPIRED') {
        expect(
          find.text(
            entry.key == 'FAILED' ? 'Payment failed' : 'Request expired',
          ),
          findsWidgets,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a temporary status error does not imply payment success', (
    tester,
  ) async {
    final pendingIntent = _intent();
    final service = _FakePaymentIntentService(
      intent: pendingIntent,
      error: StateError('temporary network failure'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: pendingIntent,
          paymentIntentService: service,
          statusPollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Awaiting customer payment'), findsOneWidget);
    expect(find.text('Payment received'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('paymentStatusRefreshError')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('paymentStatusRefreshError')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('network interruption remains uncertain and retry can confirm', (
    tester,
  ) async {
    final pendingIntent = _intent();
    final successIntent = _intent(
      status: 'SUCCESS',
      createdAt: pendingIntent.createdAt,
      expiresAt: pendingIntent.expiresAt,
    );
    final service = _FakePaymentIntentService(
      statusOutcomes: [StateError('offline'), successIntent],
    );
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: pendingIntent,
          paymentIntentService: service,
          onConfirmedSuccess: () async {
            refreshCalls++;
          },
          statusPollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Awaiting customer payment'), findsOneWidget);
    expect(find.text('Payment received'), findsNothing);
    expect(refreshCalls, 0);

    await tester.ensureVisible(
      find.byKey(const Key('refreshPaymentStatusButton')),
    );
    await tester.tap(find.byKey(const Key('refreshPaymentStatusButton')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Payment received'), findsOneWidget);
    expect(refreshCalls, 1);
    expect(service.statusCalls, 2);
  });

  testWidgets('keeps the QR scannable on a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final intent = _intent();
    final service = _FakePaymentIntentService(
      intent: intent,
      statusResponses: [intent],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentIntentQrScreen(
          paymentIntent: intent,
          paymentIntentService: service,
          statusPollInterval: const Duration(hours: 1),
          clock: () => intent.createdAt,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('paymentIntentQrCode')), findsOneWidget);
    final qr = tester.widget<QrImageView>(
      find.byKey(const Key('paymentIntentQrCode')),
    );
    expect(qr.size, 200);
    expect(tester.takeException(), isNull);
  });
}
