import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/security/local_auth_service.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/card/models/vpay_card.dart';
import 'package:vpay_mobile/features/card/services/card_api_service.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';
import 'package:vpay_mobile/features/customer/models/customer_transaction.dart';
import 'package:vpay_mobile/features/customer/services/customer_transaction_service.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_result.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_payment_preview_screen.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_qr_scanner_screen.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_confirmation_service.dart';
import 'package:vpay_mobile/features/customer_payment/services/customer_payment_preview_service.dart';

const _profile = VPayUserProfile(
  uid: 'customer-uid',
  name: 'Kasun Perera',
  email: 'kasun@example.com',
  role: 'CUSTOMER',
  status: 'ACTIVE',
);

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SuccessfulLocalAuthService implements LocalAuthService {
  int requests = 0;

  @override
  Future<bool> authenticateForSensitiveAction({required String reason}) async {
    requests++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SuccessfulConfirmationService
    implements CustomerPaymentConfirmationService {
  int requests = 0;

  @override
  Future<CustomerPaymentResult> confirmPayment(String paymentReference) async {
    requests++;
    return CustomerPaymentResult(
      paymentReference: paymentReference,
      status: CustomerPaymentStatus.success,
      transactionId: 'transaction-123',
      merchantName: 'VPay Test Merchant',
      amountMinor: 125000,
      currency: 'LKR',
      paidAt: DateTime.utc(2099, 1, 1, 0, 5),
    );
  }

  @override
  Future<CustomerPaymentResult> getPaymentStatus(String paymentReference) {
    throw UnimplementedError();
  }
}

class _FakeCardApiService extends CardApiService {
  _FakeCardApiService(this._cards);

  final List<VPayCard> _cards;
  int requests = 0;

  @override
  Future<VPayCard> getCurrentUserCard() async {
    requests++;
    return _cards.length > 1 ? _cards.removeAt(0) : _cards.single;
  }
}

class _FakeTransactionService implements CustomerTransactionService {
  int requests = 0;

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async {
    requests++;
    return const [];
  }
}

class _ControlledTransactionService implements CustomerTransactionService {
  final requests = <Completer<List<CustomerTransaction>>>[];

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) {
    final request = Completer<List<CustomerTransaction>>();
    requests.add(request);
    return request.future;
  }
}

VPayCard _cardWithBalance(num balance) {
  return VPayCard.fromJson({
    'id': 'customer-uid',
    'maskedNumber': '•••• •••• •••• 4827',
    'balance': balance,
    'status': 'ACTIVE',
    'expiresAt': '2029-09-01T00:00:00.000Z',
    'createdAt': '2026-09-01T00:00:00.000Z',
  });
}

class _SuccessfulPreviewService implements CustomerPaymentPreviewService {
  final references = <String>[];

  @override
  Future<CustomerPaymentPreview> getPreview(String paymentReference) async {
    references.add(paymentReference);
    return CustomerPaymentPreview(
      paymentReference: paymentReference,
      merchantName: 'VPay Test Merchant',
      amountMinor: 125000,
      currency: 'LKR',
      status: CustomerPaymentStatus.pending,
      createdAt: DateTime.utc(2099, 1, 1),
      expiresAt: DateTime.utc(2099, 1, 1, 0, 15),
    );
  }
}

CustomerQrScannerViewBuilder _controlsScannerBuilder() {
  return (
    BuildContext context, {
    required ValueChanged<String?> onRawValue,
    required CustomerQrScannerErrorBuilder errorBuilder,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                key: const ValueKey('emitValidQr'),
                onPressed: () => onRawValue('  payment-ref-123  '),
                child: const Text('Valid QR'),
              ),
              ElevatedButton(
                key: const ValueKey('emitEmptyQr'),
                onPressed: () => onRawValue('   '),
                child: const Text('Empty QR'),
              ),
              ElevatedButton(
                key: const ValueKey('emitNullQr'),
                onPressed: () => onRawValue(null),
                child: const Text('Null QR'),
              ),
              ElevatedButton(
                key: const ValueKey('emitDuplicateQr'),
                onPressed: () {
                  onRawValue('first-reference');
                  onRawValue('second-reference');
                },
                child: const Text('Duplicate QR'),
              ),
            ],
          ),
        ),
      ),
    );
  };
}

CustomerQrScannerViewBuilder _errorScannerBuilder(CustomerQrCameraError error) {
  return (
    BuildContext context, {
    required ValueChanged<String?> onRawValue,
    required CustomerQrScannerErrorBuilder errorBuilder,
  }) => errorBuilder(context, error);
}

class _ScannerRouteHost extends StatefulWidget {
  const _ScannerRouteHost({
    required this.scannerBuilder,
    required this.results,
  });

  final CustomerQrScannerViewBuilder scannerBuilder;
  final List<String?> results;

  @override
  State<_ScannerRouteHost> createState() => _ScannerRouteHostState();
}

class _ScannerRouteHostState extends State<_ScannerRouteHost> {
  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            CustomerQrScannerScreen(scannerBuilder: widget.scannerBuilder),
      ),
    );
    widget.results.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('openTestScanner'),
          onPressed: _openScanner,
          child: const Text('Open scanner'),
        ),
      ),
    );
  }
}

Future<void> _openTestScanner(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('openTestScanner')));
  await tester.pumpAndSettle();
}

Future<void> _openScannerFromCustomerShell(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Scan & Pay'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('scanMerchantQrButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Activity refreshes on return without duplicate requests', (
    tester,
  ) async {
    final transactions = _ControlledTransactionService();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _profile,
          authService: _FakeAuthService(),
          cardApiService: _FakeCardApiService([_cardWithBalance(20000)]),
          transactionService: transactions,
        ),
      ),
    );
    await tester.pump();
    expect(transactions.requests, hasLength(1));

    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(transactions.requests, hasLength(1));

    transactions.requests.first.complete(const []);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(transactions.requests, hasLength(2));

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(transactions.requests, hasLength(2));

    transactions.requests.last.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('Customer Home opens the existing scanner and preview flow', (
    tester,
  ) async {
    final previewService = _SuccessfulPreviewService();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _profile,
          authService: _FakeAuthService(),
          qrScannerBuilder: _controlsScannerBuilder(),
          paymentPreviewService: previewService,
          cardApiService: _FakeCardApiService([_cardWithBalance(20000)]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );

    final homeScanButton = find.byKey(const ValueKey('homeScanAndPayButton'));
    await tester.ensureVisible(homeScanButton);
    await tester.tap(homeScanButton);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPaymentPreviewScreen), findsOneWidget);
    expect(find.text('VPay Test Merchant'), findsOneWidget);
    expect(previewService.references, ['payment-ref-123']);
  });

  testWidgets('verified payment success refreshes the retained Home card', (
    tester,
  ) async {
    final cardService = _FakeCardApiService([
      _cardWithBalance(12850),
      _cardWithBalance(12850),
      _cardWithBalance(12850),
      _cardWithBalance(11600),
    ]);
    final transactionService = _FakeTransactionService();
    final confirmationService = _SuccessfulConfirmationService();
    final localAuthService = _SuccessfulLocalAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _profile,
          authService: _FakeAuthService(),
          qrScannerBuilder: _controlsScannerBuilder(),
          paymentPreviewService: _SuccessfulPreviewService(),
          paymentConfirmationService: confirmationService,
          localAuthService: localAuthService,
          cardApiService: cardService,
          transactionService: transactionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cardService.requests, 1);
    expect(find.text('Rs. 12,850.00'), findsOneWidget);

    final homeScanButton = find.byKey(const ValueKey('homeScanAndPayButton'));
    await tester.ensureVisible(homeScanButton);
    await tester.tap(homeScanButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    final confirmButton = find.byKey(const ValueKey('confirmPaymentButton'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(localAuthService.requests, 1);
    expect(confirmationService.requests, 1);
    expect(find.text('Payment successful'), findsOneWidget);
    expect(cardService.requests, 4);
    expect(transactionService.requests, 2);

    await tester.tap(find.byKey(const ValueKey('finishPaymentButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPaymentPreviewScreen), findsNothing);
    expect(find.text('Rs. 11,600.00'), findsOneWidget);
  });

  testWidgets('CustomerShell opens and closes the scanner without a result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _profile,
          authService: _FakeAuthService(),
          qrScannerBuilder: _controlsScannerBuilder(),
          paymentPreviewService: _SuccessfulPreviewService(),
          cardApiService: _FakeCardApiService([_cardWithBalance(20000)]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );

    await _openScannerFromCustomerShell(tester);
    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('closeQrScannerButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrScannerScreen), findsNothing);
    expect(find.byType(CustomerPaymentPreviewScreen), findsNothing);
  });

  testWidgets('returns a trimmed non-empty payment reference', (tester) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _controlsScannerBuilder(),
          results: results,
        ),
      ),
    );

    await _openTestScanner(tester);
    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    expect(results, ['payment-ref-123']);
  });

  testWidgets('ignores empty and null QR values', (tester) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _controlsScannerBuilder(),
          results: results,
        ),
      ),
    );

    await _openTestScanner(tester);
    await tester.tap(find.byKey(const ValueKey('emitEmptyQr')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('emitNullQr')));
    await tester.pump();

    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.byKey(const ValueKey('closeQrScannerButton')));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('returns only the first of repeated detections', (tester) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _controlsScannerBuilder(),
          results: results,
        ),
      ),
    );

    await _openTestScanner(tester);
    await tester.tap(find.byKey(const ValueKey('emitDuplicateQr')));
    await tester.pumpAndSettle();

    expect(results, ['first-reference']);
  });

  testWidgets('CustomerShell opens preview without claiming payment success', (
    tester,
  ) async {
    final previewService = _SuccessfulPreviewService();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShell(
          profile: _profile,
          authService: _FakeAuthService(),
          qrScannerBuilder: _controlsScannerBuilder(),
          paymentPreviewService: previewService,
          cardApiService: _FakeCardApiService([_cardWithBalance(20000)]),
          transactionService: _FakeTransactionService(),
        ),
      ),
    );

    await _openScannerFromCustomerShell(tester);
    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPaymentPreviewScreen), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
    expect(find.textContaining('authenticate on this device'), findsOneWidget);
    expect(find.textContaining('Payment successful'), findsNothing);
    expect(previewService.references, ['payment-ref-123']);
  });

  testWidgets('shows permission and camera initialization errors', (
    tester,
  ) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _errorScannerBuilder(
            CustomerQrCameraError.permissionDenied,
          ),
          results: results,
        ),
      ),
    );

    await _openTestScanner(tester);
    expect(find.text('Camera permission required'), findsOneWidget);
    expect(find.byKey(const ValueKey('retryQrCameraButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('closeQrScannerButton')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _errorScannerBuilder(
            CustomerQrCameraError.unavailable,
          ),
          results: results,
        ),
      ),
    );
    await _openTestScanner(tester);
    expect(find.text('Camera unavailable'), findsOneWidget);
  });

  testWidgets('scanner layout fits a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _ScannerRouteHost(
          scannerBuilder: _controlsScannerBuilder(),
          results: results,
        ),
      ),
    );

    await _openTestScanner(tester);
    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
