import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _electric = Color(0xFF0072DC);
const _arc = Color(0xFF27BAFF);
const _void = Color(0xFF000815);

enum CustomerQrCameraError { permissionDenied, unavailable }

typedef CustomerQrScannerErrorBuilder =
    Widget Function(BuildContext context, CustomerQrCameraError error);

typedef CustomerQrScannerViewBuilder =
    Widget Function(
      BuildContext context, {
      required ValueChanged<String?> onRawValue,
      required CustomerQrScannerErrorBuilder errorBuilder,
    });

class CustomerQrScannerScreen extends StatefulWidget {
  const CustomerQrScannerScreen({super.key, this.scannerBuilder});

  final CustomerQrScannerViewBuilder? scannerBuilder;

  @override
  State<CustomerQrScannerScreen> createState() =>
      _CustomerQrScannerScreenState();
}

class _CustomerQrScannerScreenState extends State<CustomerQrScannerScreen> {
  bool _didReturnReference = false;
  int _scannerGeneration = 0;

  void _handleRawValue(String? rawValue) {
    if (_didReturnReference) return;

    final paymentReference = rawValue?.trim();
    if (paymentReference == null || paymentReference.isEmpty) return;

    _didReturnReference = true;
    Navigator.of(context).pop(paymentReference);
  }

  void _retryCamera() {
    setState(() => _scannerGeneration++);
  }

  void _closeScanner() {
    Navigator.of(context).pop();
  }

  Widget _buildMobileScanner(
    BuildContext context, {
    required ValueChanged<String?> onRawValue,
    required CustomerQrScannerErrorBuilder errorBuilder,
  }) {
    return MobileScanner(
      key: ValueKey(_scannerGeneration),
      useAppLifecycleState: true,
      fit: BoxFit.cover,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.format != BarcodeFormat.qrCode) continue;

          final rawValue = barcode.rawValue;
          if (rawValue == null || rawValue.trim().isEmpty) continue;

          onRawValue(rawValue);
          return;
        }
      },
      placeholderBuilder: (context) => const ColoredBox(
        color: _void,
        child: Center(child: CircularProgressIndicator(color: _arc)),
      ),
      errorBuilder: (context, error) {
        final cameraError =
            error.errorCode == MobileScannerErrorCode.permissionDenied
            ? CustomerQrCameraError.permissionDenied
            : CustomerQrCameraError.unavailable;
        return errorBuilder(context, cameraError);
      },
      overlayBuilder: (context, constraints) => const Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ScannerOverlayPainter()),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _ScannerInstruction(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError(BuildContext context, CustomerQrCameraError error) {
    final permissionDenied = error == CustomerQrCameraError.permissionDenied;

    return ColoredBox(
      color: _void,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.camera_alt_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 18),
              Text(
                permissionDenied
                    ? 'Camera permission required'
                    : 'Camera unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                permissionDenied
                    ? 'Allow camera access to scan a merchant QR code. If permission was permanently denied, enable it in your device settings.'
                    : 'VPay could not start the camera. Check that another app is not using it, then try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD7E2EF),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('retryQrCameraButton'),
                  onPressed: _retryCamera,
                  style: FilledButton.styleFrom(
                    backgroundColor: _electric,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _closeScanner,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanner = (widget.scannerBuilder ?? _buildMobileScanner)(
      context,
      onRawValue: _handleRawValue,
      errorBuilder: _buildCameraError,
    );

    return Scaffold(
      backgroundColor: _void,
      body: Stack(
        fit: StackFit.expand,
        children: [
          scanner,
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const ValueKey('closeQrScannerButton'),
                        onPressed: _closeScanner,
                        tooltip: 'Close scanner',
                        color: _electric,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Scan Merchant QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerInstruction extends StatelessWidget {
  const _ScannerInstruction();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xCC000815),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x5527BAFF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: _arc),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Align the merchant QR code inside the frame.',
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = math.min(
      size.width * 0.72,
      math.min(size.height * 0.42, 280.0),
    );
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.48),
      width: frameSize,
      height: frameSize,
    );
    final frame = RRect.fromRectAndRadius(frameRect, const Radius.circular(22));

    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(scrimPath, Paint()..color = const Color(0x8F000815));

    final accentPaint = Paint()
      ..color = _arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cornerLength = 32.0;

    final left = frameRect.left;
    final right = frameRect.right;
    final top = frameRect.top;
    final bottom = frameRect.bottom;

    canvas
      ..drawLine(
        Offset(left, top + cornerLength),
        Offset(left, top),
        accentPaint,
      )
      ..drawLine(
        Offset(left, top),
        Offset(left + cornerLength, top),
        accentPaint,
      )
      ..drawLine(
        Offset(right - cornerLength, top),
        Offset(right, top),
        accentPaint,
      )
      ..drawLine(
        Offset(right, top),
        Offset(right, top + cornerLength),
        accentPaint,
      )
      ..drawLine(
        Offset(left, bottom - cornerLength),
        Offset(left, bottom),
        accentPaint,
      )
      ..drawLine(
        Offset(left, bottom),
        Offset(left + cornerLength, bottom),
        accentPaint,
      )
      ..drawLine(
        Offset(right - cornerLength, bottom),
        Offset(right, bottom),
        accentPaint,
      )
      ..drawLine(
        Offset(right, bottom),
        Offset(right, bottom - cornerLength),
        accentPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => false;
}
