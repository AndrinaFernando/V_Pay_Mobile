import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_payment_preview_screen.dart';
import 'package:vpay_mobile/features/customer_payment/screens/customer_qr_scanner_screen.dart';
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

class _SuccessfulPreviewService implements CustomerPaymentPreviewService {
  final references = <String>[];

  @override
  Future<CustomerPaymentPreview> getPreview(String paymentReference) async {
    references.add(paymentReference);
    return CustomerPaymentPreview(
      merchantUid: 'merchant-uid',
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
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('homeScanAndPayButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrScannerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPaymentPreviewScreen), findsOneWidget);
    expect(find.text('VPay Test Merchant'), findsOneWidget);
    expect(previewService.references, ['payment-ref-123']);
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
        ),
      ),
    );

    await _openScannerFromCustomerShell(tester);
    await tester.tap(find.byKey(const ValueKey('emitValidQr')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPaymentPreviewScreen), findsOneWidget);
    expect(find.text('Payment confirmation unavailable'), findsOneWidget);
    expect(find.textContaining('No payment has been made'), findsOneWidget);
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
