import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/security/local_auth_service.dart';
import 'package:vpay_mobile/features/card/models/vpay_card.dart';
import 'package:vpay_mobile/features/card/services/card_api_service.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_balance_check.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_result.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_payment_preview_screen.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_confirmation_service.dart';
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

class _FakeLocalAuthService implements LocalAuthService {
  _FakeLocalAuthService(this.authenticate);

  final Future<bool> Function(String reason) authenticate;
  final reasons = <String>[];

  @override
  Future<bool> authenticateForSensitiveAction({required String reason}) {
    reasons.add(reason);
    return authenticate(reason);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _PaymentResponse = Future<CustomerPaymentResult> Function();

class _FakeCardApiService extends CardApiService {
  _FakeCardApiService({List<num> balances = const [20000]})
    : _balances = List.of(balances);

  final List<num> _balances;
  int requests = 0;

  @override
  Future<VPayCard> getCurrentUserCard() async {
    requests++;
    final balance = _balances.length > 1
        ? _balances.removeAt(0)
        : _balances.single;
    return VPayCard(
      id: 'customer-uid',
      maskedNumber: '•••• 4827',
      balance: balance,
      status: 'ACTIVE',
      expiresAt: DateTime.utc(2099),
      createdAt: DateTime.utc(2026),
    );
  }
}

class _FakeConfirmationService implements CustomerPaymentConfirmationService {
  _FakeConfirmationService({
    required List<_PaymentResponse> confirmations,
    List<_PaymentResponse> statuses = const [],
  }) : _confirmations = List.of(confirmations),
       _statuses = List.of(statuses);

  final List<_PaymentResponse> _confirmations;
  final List<_PaymentResponse> _statuses;
  final confirmationReferences = <String>[];
  final statusReferences = <String>[];

  @override
  Future<CustomerPaymentResult> confirmPayment(String paymentReference) {
    confirmationReferences.add(paymentReference);
    return _confirmations.removeAt(0)();
  }

  @override
  Future<CustomerPaymentResult> getPaymentStatus(String paymentReference) {
    statusReferences.add(paymentReference);
    return _statuses.removeAt(0)();
  }
}

CustomerPaymentPreview _preview({
  CustomerPaymentStatus status = CustomerPaymentStatus.pending,
  DateTime? expiresAt,
  String? description = 'Lunch order',
  int amountMinor = 1285050,
}) {
  return CustomerPaymentPreview(
    paymentReference: 'payment-ref-123',
    merchantName: 'Colombo Cafe',
    amountMinor: amountMinor,
    currency: 'LKR',
    status: status,
    createdAt: DateTime.utc(2099, 2, 3, 8),
    expiresAt: expiresAt ?? DateTime.utc(2099, 2, 3, 8, 15),
    description: description,
  );
}

CustomerPaymentResult _paymentResult({
  CustomerPaymentStatus status = CustomerPaymentStatus.success,
  String paymentReference = 'payment-ref-123',
  int amountMinor = 1285050,
  String currency = 'LKR',
}) {
  if (status != CustomerPaymentStatus.success) {
    return CustomerPaymentResult(
      paymentReference: paymentReference,
      status: status,
    );
  }
  return CustomerPaymentResult(
    transactionId: 'qr-payment--$paymentReference',
    paymentReference: paymentReference,
    merchantName: 'Colombo Cafe',
    amountMinor: amountMinor,
    currency: currency,
    status: status,
    paidAt: DateTime.utc(2099, 2, 3, 8, 5),
  );
}

Future<void> _pumpPreview(
  WidgetTester tester,
  CustomerPaymentPreviewService service, {
  CustomerPaymentConfirmationService? confirmationService,
  LocalAuthService? localAuthService,
  CardApiService? cardApiService,
  ValueChanged<CustomerPaymentResult>? onPaymentSuccess,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CustomerPaymentPreviewScreen(
        paymentReference: 'payment-ref-123',
        previewService: service,
        confirmationService: confirmationService,
        localAuthService: localAuthService,
        cardApiService: cardApiService ?? _FakeCardApiService(),
        onPaymentSuccess: onPaymentSuccess,
      ),
    ),
  );
}

Future<void> _tapConfirm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('confirmPaymentButton'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

void main() {
  test('formats LKR minor units without an extra dependency', () {
    expect(formatLkrMinor(0), 'Rs. 0.00');
    expect(formatLkrMinor(105), 'Rs. 1.05');
    expect(formatLkrMinor(1285050), 'Rs. 12,850.50');
  });

  test(
    'retained balance check allows exact equality and rejects invalid data',
    () {
      expect(
        checkCustomerPaymentBalance(
          balance: 1500,
          amountMinor: 100000,
        ).isAllowed,
        isTrue,
      );
      expect(
        checkCustomerPaymentBalance(
          balance: 1499.99,
          amountMinor: 100000,
        ).outcome,
        CustomerPaymentBalanceOutcome.minimumRetainedBalanceRequired,
      );
      expect(
        checkCustomerPaymentBalance(balance: 100, amountMinor: 0).outcome,
        CustomerPaymentBalanceOutcome.invalidAmount,
      );
      expect(
        checkCustomerPaymentBalance(
          balance: double.nan,
          amountMinor: 1000,
        ).outcome,
        CustomerPaymentBalanceOutcome.invalidBalance,
      );
    },
  );

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
    expect(find.text('Confirm Payment'), findsOneWidget);
    expect(
      find.text(
        'Review these verified details, then select Confirm Payment to continue.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('not implemented'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Confirm Payment'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(service.references, ['payment-ref-123']);
  });

  testWidgets('authenticates before submitting and shows confirmed success', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final auth = _FakeLocalAuthService((_) async => true);
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult()],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: auth,
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(auth.reasons, ['Authenticate to pay Rs. 12,850.50 to Colombo Cafe']);
    expect(confirmation.confirmationReferences, ['payment-ref-123']);
    expect(successfulResults, hasLength(1));
    expect(successfulResults.single.paymentReference, 'payment-ref-123');
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('qr-payment--payment-ref-123'), findsOneWidget);
  });

  testWidgets('does not submit when device authentication is cancelled', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final auth = _FakeLocalAuthService((_) async => false);
    final confirmation = _FakeConfirmationService(confirmations: []);

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: auth,
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(confirmation.confirmationReferences, isEmpty);
    expect(successfulResults, isEmpty);
    expect(find.textContaining('No payment was submitted'), findsOneWidget);
  });

  testWidgets('does not submit when device authentication fails', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final auth = _FakeLocalAuthService(
      (_) => Future<bool>.error(StateError('authentication unavailable')),
    );
    final confirmation = _FakeConfirmationService(confirmations: []);

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: auth,
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(confirmation.confirmationReferences, isEmpty);
    expect(successfulResults, isEmpty);
    expect(find.textContaining('could not be completed'), findsOneWidget);
  });

  testWidgets('ignores duplicate confirmation taps while work is in progress', (
    tester,
  ) async {
    final authCompleter = Completer<bool>();
    final confirmationCompleter = Completer<CustomerPaymentResult>();
    final auth = _FakeLocalAuthService((_) => authCompleter.future);
    final confirmation = _FakeConfirmationService(
      confirmations: [() => confirmationCompleter.future],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: auth,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmPaymentButton')));
    await tester.pump();
    expect(auth.reasons, hasLength(1));

    authCompleter.complete(true);
    await tester.pump();
    await tester.pump();
    expect(confirmation.confirmationReferences, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('confirmPaymentButton')));
    await tester.pump();
    expect(confirmation.confirmationReferences, hasLength(1));

    confirmationCompleter.complete(_paymentResult());
    await tester.pumpAndSettle();
    expect(find.text('Payment successful'), findsOneWidget);
  });

  testWidgets('shows a red retained-balance error and blocks authentication', (
    tester,
  ) async {
    final auth = _FakeLocalAuthService((_) async => true);
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult(amountMinor: 1000)],
    );
    final card = _FakeCardApiService(balances: const [509]);

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview(amountMinor: 1000)]),
      confirmationService: confirmation,
      localAuthService: auth,
      cardApiService: card,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('paymentBalanceError')), findsOneWidget);
    expect(find.textContaining('Rs. 9.00'), findsOneWidget);

    await _tapConfirm(tester);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('paymentBalanceErrorSnackBar')),
      findsOneWidget,
    );
    expect(auth.reasons, isEmpty);
    expect(confirmation.confirmationReferences, isEmpty);

    ScaffoldMessenger.of(
      tester.element(find.byKey(const ValueKey('confirmPaymentButton'))),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('paymentBalanceErrorSnackBar')),
      findsNothing,
    );
  });

  testWidgets('allows a payment that leaves exactly Rs. 500', (tester) async {
    final auth = _FakeLocalAuthService((_) async => true);
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult(amountMinor: 1000)],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview(amountMinor: 1000)]),
      confirmationService: confirmation,
      localAuthService: auth,
      cardApiService: _FakeCardApiService(balances: const [510]),
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(auth.reasons, hasLength(1));
    expect(confirmation.confirmationReferences, ['payment-ref-123']);
    expect(find.text('Payment successful'), findsOneWidget);
  });

  testWidgets('rechecks a changed balance before device authentication', (
    tester,
  ) async {
    final auth = _FakeLocalAuthService((_) async => true);
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult(amountMinor: 1000)],
    );
    final card = _FakeCardApiService(balances: const [1000, 505]);

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview(amountMinor: 1000)]),
      confirmationService: confirmation,
      localAuthService: auth,
      cardApiService: card,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paymentBalanceError')), findsNothing);

    await _tapConfirm(tester);
    await tester.pump();
    await tester.pump();

    expect(card.requests, 2);
    expect(find.textContaining('Rs. 5.00'), findsWidgets);
    expect(auth.reasons, isEmpty);
    expect(confirmation.confirmationReferences, isEmpty);
  });

  testWidgets('shows a clear known backend rejection', (tester) async {
    final successfulResults = <CustomerPaymentResult>[];
    final confirmation = _FakeConfirmationService(
      confirmations: [
        () => Future.error(
          const CustomerPaymentConfirmationException(
            CustomerPaymentConfirmationFailure.minimumBalanceRequired,
          ),
        ),
      ],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: _FakeLocalAuthService((_) async => true),
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('required Rs. 500 retained balance'),
      findsWidgets,
    );
    expect(successfulResults, isEmpty);
    expect(find.text('Payment successful'), findsNothing);
  });

  testWidgets('recovers a timed-out confirmation through status only', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final confirmation = _FakeConfirmationService(
      confirmations: [
        () => Future.error(
          const CustomerPaymentConfirmationException(
            CustomerPaymentConfirmationFailure.ambiguousNetwork,
          ),
        ),
      ],
      statuses: [() async => _paymentResult()],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: _FakeLocalAuthService((_) async => true),
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(confirmation.confirmationReferences, ['payment-ref-123']);
    expect(confirmation.statusReferences, ['payment-ref-123']);
    expect(successfulResults, hasLength(1));
    expect(find.text('Payment successful'), findsOneWidget);
  });

  testWidgets('notifies verified payment success only once per screen', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final previewService = _FakePreviewService([() async => _preview()]);
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult()],
    );
    final auth = _FakeLocalAuthService((_) async => true);

    await _pumpPreview(
      tester,
      previewService,
      confirmationService: confirmation,
      localAuthService: auth,
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(successfulResults, hasLength(1));

    await _pumpPreview(
      tester,
      previewService,
      confirmationService: confirmation,
      localAuthService: auth,
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(successfulResults, hasLength(1));
  });

  testWidgets('recovers a mismatched receipt amount through status only', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult(amountMinor: 1285051)],
      statuses: [() async => _paymentResult()],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: _FakeLocalAuthService((_) async => true),
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(confirmation.confirmationReferences, ['payment-ref-123']);
    expect(confirmation.statusReferences, ['payment-ref-123']);
    expect(successfulResults, hasLength(1));
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Rs. 12,850.50'), findsOneWidget);
  });

  testWidgets('keeps a mismatched receipt currency uncertain', (tester) async {
    final successfulResults = <CustomerPaymentResult>[];
    final confirmation = _FakeConfirmationService(
      confirmations: [() async => _paymentResult(currency: 'USD')],
      statuses: [() async => _paymentResult(currency: 'USD')],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: _FakeLocalAuthService((_) async => true),
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(confirmation.confirmationReferences, ['payment-ref-123']);
    expect(confirmation.statusReferences, ['payment-ref-123']);
    expect(successfulResults, isEmpty);
    expect(find.text('Payment result unknown'), findsOneWidget);
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(find.text('Payment successful'), findsNothing);
  });

  testWidgets('shows an unknown result when status recovery also fails', (
    tester,
  ) async {
    final successfulResults = <CustomerPaymentResult>[];
    final confirmation = _FakeConfirmationService(
      confirmations: [
        () => Future.error(
          const CustomerPaymentConfirmationException(
            CustomerPaymentConfirmationFailure.ambiguousNetwork,
          ),
        ),
      ],
      statuses: [
        () => Future.error(
          const CustomerPaymentConfirmationException(
            CustomerPaymentConfirmationFailure.ambiguousNetwork,
          ),
        ),
      ],
    );

    await _pumpPreview(
      tester,
      _FakePreviewService([() async => _preview()]),
      confirmationService: confirmation,
      localAuthService: _FakeLocalAuthService((_) async => true),
      onPaymentSuccess: successfulResults.add,
    );
    await tester.pumpAndSettle();
    await _tapConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.text('Payment result unknown'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkPaymentStatusButton')),
      findsOneWidget,
    );
    expect(confirmation.confirmationReferences, hasLength(1));
    expect(confirmation.statusReferences, hasLength(1));
    expect(successfulResults, isEmpty);
  });

  for (final status in [
    CustomerPaymentStatus.pending,
    CustomerPaymentStatus.processing,
  ]) {
    testWidgets('does not notify while recovered payment is ${status.name}', (
      tester,
    ) async {
      final successfulResults = <CustomerPaymentResult>[];
      final confirmation = _FakeConfirmationService(
        confirmations: [
          () => Future.error(
            const CustomerPaymentConfirmationException(
              CustomerPaymentConfirmationFailure.ambiguousNetwork,
            ),
          ),
        ],
        statuses: [() async => _paymentResult(status: status)],
      );

      await _pumpPreview(
        tester,
        _FakePreviewService([() async => _preview()]),
        confirmationService: confirmation,
        localAuthService: _FakeLocalAuthService((_) async => true),
        onPaymentSuccess: successfulResults.add,
      );
      await tester.pumpAndSettle();
      await _tapConfirm(tester);
      await tester.pumpAndSettle();

      expect(successfulResults, isEmpty);
      expect(find.text('Payment successful'), findsNothing);
      expect(
        find.byKey(const ValueKey('checkPaymentStatusButton')),
        findsOneWidget,
      );
    });
  }

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
    CustomerPaymentPreviewFailure.customerProfileNotFound:
        'Customer profile not found',
    CustomerPaymentPreviewFailure.expired: 'Payment expired',
    CustomerPaymentPreviewFailure.alreadyUsed: 'Payment already used',
    CustomerPaymentPreviewFailure.authentication: 'Session verification failed',
    CustomerPaymentPreviewFailure.accountNotReady: 'QR payments unavailable',
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
      if (entry.key == CustomerPaymentPreviewFailure.authentication) {
        expect(find.textContaining('authenticated session'), findsOneWidget);
        expect(find.textContaining('account is active'), findsNothing);
      }
      if (entry.key == CustomerPaymentPreviewFailure.accountNotReady) {
        expect(
          find.textContaining('cannot currently access QR payment previews'),
          findsOneWidget,
        );
        expect(find.textContaining('account is active'), findsOneWidget);
        expect(find.textContaining('sign in again'), findsNothing);
      }
      if (entry.key == CustomerPaymentPreviewFailure.customerProfileNotFound) {
        expect(
          find.textContaining('Complete your account setup'),
          findsOneWidget,
        );
        expect(find.textContaining('contact VPay support'), findsOneWidget);
      }
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
