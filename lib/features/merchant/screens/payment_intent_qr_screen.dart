import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../models/merchant_payment_intent.dart';
import '../services/payment_intent_service.dart';

const _canvas = Color(0xFFFCF9F8);
const _surface = Colors.white;
const _ink = Color(0xFF222222);
const _supporting = Color(0xFF484848);
const _secondary = Color(0xFF767676);
const _divider = Color(0xFFEBEBEB);
const _electric = Color(0xFF0072DC);
const _navy = Color(0xFF00193C);
const _success = Color(0xFF008A05);
const _warning = Color(0xFFD58B22);
const _error = Color(0xFFC74A4A);

class PaymentIntentQrScreen extends StatefulWidget {
  const PaymentIntentQrScreen({
    super.key,
    required this.paymentIntent,
    this.paymentIntentService,
    this.statusPollInterval = const Duration(seconds: 5),
    this.clock,
  });

  final MerchantPaymentIntent paymentIntent;
  final PaymentIntentService? paymentIntentService;
  final Duration statusPollInterval;
  final DateTime Function()? clock;

  @override
  State<PaymentIntentQrScreen> createState() => _PaymentIntentQrScreenState();
}

class _PaymentIntentQrScreenState extends State<PaymentIntentQrScreen> {
  late final PaymentIntentService _service;
  late MerchantPaymentIntent _currentIntent;
  late Duration _remaining;
  Timer? _clockTimer;
  Timer? _statusTimer;
  bool _isRefreshing = false;
  bool _expiryCheckStarted = false;
  String? _refreshError;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  bool get _isPending => _currentIntent.status == 'PENDING';

  bool get _canRefreshStatus =>
      _isPending || _currentIntent.status == 'PROCESSING';

  bool get _hasExpiredByTime => _remaining <= Duration.zero;

  bool get _showQr => _isPending && !_hasExpiredByTime;

  @override
  void initState() {
    super.initState();
    _service = widget.paymentIntentService ?? ApiPaymentIntentService();
    _currentIntent = widget.paymentIntent;
    _remaining = _timeRemaining();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
    _statusTimer = Timer.periodic(widget.statusPollInterval, (_) {
      unawaited(_refreshStatus());
    });
    if (!_canRefreshStatus) {
      _statusTimer?.cancel();
      _clockTimer?.cancel();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canRefreshStatus) unawaited(_refreshStatus());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Duration _timeRemaining() {
    final duration = _currentIntent.expiresAt.difference(_now);
    return duration.isNegative ? Duration.zero : duration;
  }

  void _updateCountdown() {
    if (!_isPending) return;
    final remaining = _timeRemaining();
    if (remaining == _remaining) return;
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero && !_expiryCheckStarted) {
      _expiryCheckStarted = true;
      unawaited(_refreshStatus());
    }
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing || !_canRefreshStatus) return;
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });

    try {
      final latest = await _service.getPaymentIntent(
        paymentReference: _currentIntent.paymentReference,
      );
      if (!_isValidStatusResponse(latest)) {
        throw const ApiException(
          200,
          'VPay returned an invalid payment status.',
        );
      }
      if (!mounted) return;

      setState(() {
        _currentIntent = latest;
        _remaining = _timeRemaining();
        _refreshError = null;
      });

      if (!_canRefreshStatus) {
        _statusTimer?.cancel();
        _clockTimer?.cancel();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _refreshError = 'Unable to refresh payment status. Retrying…';
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  bool _isValidStatusResponse(MerchantPaymentIntent latest) {
    const validStatuses = {
      'PENDING',
      'PROCESSING',
      'SUCCESS',
      'FAILED',
      'EXPIRED',
    };
    return latest.paymentReference == _currentIntent.paymentReference &&
        latest.amountMinor == _currentIntent.amountMinor &&
        latest.currency == _currentIntent.currency &&
        latest.expiresAt.isAtSameMomentAs(_currentIntent.expiresAt) &&
        validStatuses.contains(latest.status);
  }

  String get _statusLabel {
    if (_currentIntent.status == 'SUCCESS') return 'Payment received';
    if (_currentIntent.status == 'PROCESSING') return 'Payment processing';
    if (_currentIntent.status == 'FAILED') return 'Payment failed';
    if (_currentIntent.status == 'EXPIRED') return 'Request expired';
    if (_hasExpiredByTime) return 'Confirming expiry with VPay';
    return 'Awaiting customer payment';
  }

  Color get _statusColor {
    return switch (_currentIntent.status) {
      'SUCCESS' => _success,
      'PROCESSING' => _warning,
      'FAILED' => _error,
      'EXPIRED' => _secondary,
      _ => _electric,
    };
  }

  String get _expiryTime {
    final local = _currentIntent.expiresAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
  }

  String get _countdownText {
    if (!_isPending && _currentIntent.status == 'EXPIRED') return 'Expired';
    if (!_isPending) return '—';
    if (_hasExpiredByTime) return '00:00';
    final totalSeconds = _remaining.inSeconds;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes >= 60) {
      final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '${totalMinutes.toString().padLeft(2, '0')}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Payment Request',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _buildStatusBanner(),
                const SizedBox(height: 14),
                _buildQrCard(),
                const SizedBox(height: 14),
                _buildExpiryCard(),
                const SizedBox(height: 14),
                _buildReferenceCard(),
                if (_refreshError != null) ...[
                  const SizedBox(height: 12),
                  _buildRefreshError(),
                ],
                const SizedBox(height: 14),
                Text(
                  _instructionText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (_currentIntent.status == 'EXPIRED' ||
                    _currentIntent.status == 'FAILED') ...[
                  const SizedBox(height: 20),
                  _buildCreateNewButton(context),
                ],
                if (_currentIntent.status == 'SUCCESS') ...[
                  const SizedBox(height: 20),
                  _buildDoneButton(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _instructionText {
    if (_currentIntent.status == 'SUCCESS') {
      return 'VPay confirmed this payment with the backend.';
    }
    if (_currentIntent.status == 'PROCESSING') {
      return 'The backend is processing this payment. Keep this screen open while VPay checks for the final result.';
    }
    if (_currentIntent.status == 'FAILED') {
      return 'The backend could not complete this payment request.';
    }
    if (_currentIntent.status == 'EXPIRED') {
      return 'This request can no longer be paid. Create a new request to continue.';
    }
    if (_hasExpiredByTime) {
      return 'The countdown has ended. VPay is checking the request status.';
    }
    return 'Ask your customer to scan this code in VPay. Payment status is refreshed from the backend.';
  }

  Widget _buildStatusBanner() {
    final status = _currentIntent.status;
    final dotColor = status == 'PENDING' && _hasExpiredByTime
        ? _warning
        : _statusColor;
    return Container(
      key: const Key('paymentStatusBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                key: Key('paymentStatusLoadingIndicator'),
                strokeWidth: 2,
                color: _electric,
              ),
            )
          else if (_canRefreshStatus)
            TextButton(
              key: const Key('refreshPaymentStatusButton'),
              onPressed: () => unawaited(_refreshStatus()),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 40),
                foregroundColor: _electric,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Refresh'),
            )
          else
            _StatusPill(status: status, color: _statusColor),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final qrBoxSize = (MediaQuery.sizeOf(context).width - 96).clamp(
      160.0,
      264.0,
    );
    final qrSize = qrBoxSize - 24;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _currentIntent.merchantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _StatusPill(status: _currentIntent.status, color: _statusColor),
          const SizedBox(height: 18),
          Container(
            width: qrBoxSize,
            height: qrBoxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: _showQr
                ? QrImageView(
                    key: const Key('paymentIntentQrCode'),
                    data: _currentIntent.qrPayload,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.Q,
                    size: qrSize,
                    padding: const EdgeInsets.all(8),
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _navy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _navy,
                    ),
                    semanticsLabel: 'Payment reference QR code',
                    errorStateBuilder: (context, error) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Unable to display this QR code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _error),
                      ),
                    ),
                  )
                : _buildQrUnavailableState(),
          ),
          const SizedBox(height: 18),
          Text(
            _formatLkr(_currentIntent.amountMinor),
            key: const Key('paymentIntentAmount'),
            style: const TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (_currentIntent.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              _currentIntent.description!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _supporting, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrUnavailableState() {
    final label = _currentIntent.status == 'EXPIRED' || _hasExpiredByTime
        ? 'Request expired'
        : 'QR code unavailable';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _currentIntent.status == 'EXPIRED' || _hasExpiredByTime
              ? Icons.timer_off_outlined
              : Icons.qr_code_2_rounded,
          size: 44,
          color: _secondary,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _supporting,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryCard() {
    final expired = _currentIntent.status == 'EXPIRED';
    return Container(
      key: const Key('paymentExpiryCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.timer_off_outlined : Icons.hourglass_bottom_rounded,
            color: expired ? _secondary : _electric,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired
                      ? 'Session expired'
                      : _hasExpiredByTime
                      ? 'Checking expiry'
                      : 'Session expiry',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Expires at $_expiryTime',
                  key: const Key('serverExpiryTime'),
                  style: const TextStyle(color: _secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _countdownText,
            key: const Key('paymentCountdown'),
            style: TextStyle(
              color: expired || _hasExpiredByTime ? _secondary : _electric,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAYMENT REFERENCE',
            style: TextStyle(
              color: _secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            _currentIntent.paymentReference,
            key: const Key('paymentReference'),
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _refreshError!,
              key: const Key('paymentStatusRefreshError'),
              style: const TextStyle(color: _supporting, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _isRefreshing ? null : () => unawaited(_refreshStatus()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewButton(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        key: const Key('createNewPaymentRequestButton'),
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(
          backgroundColor: _electric,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create New Payment Request',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: _electric,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: _divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.done_rounded),
      label: const Text('Done'),
    );
  }

  String _formatLkr(int amountMinor) {
    final wholeAmount = amountMinor ~/ 100;
    final decimal = (amountMinor % 100).toString().padLeft(2, '0');
    final digits = wholeAmount.toString();
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
      grouped.write(digits[index]);
    }
    return 'LKR $grouped.$decimal';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  String get _label => switch (status) {
    'SUCCESS' => 'Success',
    'PROCESSING' => 'Processing',
    'PENDING' => 'Pending',
    'FAILED' => 'Failed',
    'EXPIRED' => 'Expired',
    _ => 'Pending',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('paymentStatusPill'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
