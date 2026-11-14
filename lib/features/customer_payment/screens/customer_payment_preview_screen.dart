import 'package:flutter/material.dart';

import '../models/customer_payment_preview.dart';
import '../services/customer_payment_preview_service.dart';

const _electric = Color(0xFF0072DC);
const _arc = Color(0xFF27BAFF);
const _ink = Color(0xFF222222);
const _body = Color(0xFF484848);
const _secondary = Color(0xFF767676);
const _surface = Color(0xFFF7F7F7);
const _divider = Color(0xFFEBEBEB);
const _warning = Color(0xFFF59E0B);
const _error = Color(0xFFEF4444);
const _success = Color(0xFF10B981);

class CustomerPaymentPreviewScreen extends StatefulWidget {
  const CustomerPaymentPreviewScreen({
    super.key,
    required this.paymentReference,
    this.previewService,
  });

  final String paymentReference;
  final CustomerPaymentPreviewService? previewService;

  @override
  State<CustomerPaymentPreviewScreen> createState() =>
      _CustomerPaymentPreviewScreenState();
}

class _CustomerPaymentPreviewScreenState
    extends State<CustomerPaymentPreviewScreen> {
  late final CustomerPaymentPreviewService _previewService;
  CustomerPaymentPreview? _preview;
  CustomerPaymentPreviewFailure? _failure;
  bool _isLoading = true;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _previewService =
        widget.previewService ?? ApiCustomerPaymentPreviewService();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final preview = await _previewService.getPreview(widget.paymentReference);
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    } on CustomerPaymentPreviewException catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _preview = null;
        _failure = error.failure;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _preview = null;
        _failure = CustomerPaymentPreviewFailure.unavailable;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _electric,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const ValueKey('closePaymentPreviewButton'),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Payment Preview',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _PreviewLoading(
        key: const ValueKey('paymentPreviewLoading'),
        paymentReference: widget.paymentReference,
      );
    }

    final failure = _failure;
    if (failure != null) {
      return _PreviewError(
        key: ValueKey('paymentPreviewError-${failure.name}'),
        failure: failure,
        onRetry: _loadPreview,
      );
    }

    return _PreviewDetails(
      key: const ValueKey('paymentPreviewDetails'),
      paymentReference: widget.paymentReference,
      preview: _preview!,
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading({super.key, required this.paymentReference});

  final String paymentReference;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _arc),
            const SizedBox(height: 20),
            const Text(
              'Loading payment details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'VPay is securely retrieving this payment from the server.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              paymentReference,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final CustomerPaymentPreviewFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _errorCopy(failure);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: copy.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(copy.icon, color: copy.color, size: 36),
              ),
              const SizedBox(height: 22),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                copy.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('retryPaymentPreviewButton'),
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: _electric,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewDetails extends StatelessWidget {
  const _PreviewDetails({
    super.key,
    required this.paymentReference,
    required this.preview,
  });

  final String paymentReference;
  final CustomerPaymentPreview preview;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(preview, DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: _electric,
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'Review payment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'These details were retrieved securely from VPay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _divider),
                ),
                child: Column(
                  children: [
                    Text(
                      preview.merchantName,
                      key: const ValueKey('previewMerchantName'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _body,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatLkrMinor(preview.amountMinor),
                      key: const ValueKey('previewAmount'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusChip(status: status),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailsCard(
                paymentReference: paymentReference,
                preview: preview,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(status.icon, color: status.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status.message,
                        key: const ValueKey('previewStatusMessage'),
                        style: const TextStyle(
                          color: _body,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('confirmPaymentButton'),
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: _divider,
                    disabledForegroundColor: _secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text(
                    'Payment confirmation unavailable',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'No payment has been made. Confirmation will be enabled in a future step.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.paymentReference, required this.preview});

  final String paymentReference;
  final CustomerPaymentPreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Payment reference', value: paymentReference),
          if (preview.description != null)
            _DetailRow(label: 'Description', value: preview.description!),
          _DetailRow(label: 'Status', value: preview.status.apiValue),
          _DetailRow(
            label: 'Expires',
            value: _formatDateTime(preview.expiresAt),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: _secondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _StatusPresentation status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String label;
  final String message;
  final Color color;
  final IconData icon;
}

_StatusPresentation _statusPresentation(
  CustomerPaymentPreview preview,
  DateTime now,
) {
  if (preview.isExpiredAt(now)) {
    return const _StatusPresentation(
      label: 'EXPIRED',
      message: 'This payment request has expired. Scan a newly generated merchant QR code.',
      color: _error,
      icon: Icons.schedule_rounded,
    );
  }

  return switch (preview.status) {
    CustomerPaymentStatus.pending => const _StatusPresentation(
      label: 'PENDING',
      message: 'Payment details are available for review, but confirmation is not implemented yet.',
      color: _warning,
      icon: Icons.info_outline_rounded,
    ),
    CustomerPaymentStatus.processing => const _StatusPresentation(
      label: 'PROCESSING',
      message:
          'This payment is already being processed and cannot be used again.',
      color: _warning,
      icon: Icons.hourglass_top_rounded,
    ),
    CustomerPaymentStatus.success => const _StatusPresentation(
      label: 'SUCCESS',
      message: 'This payment has already been completed and cannot be reused.',
      color: _success,
      icon: Icons.check_circle_outline_rounded,
    ),
    CustomerPaymentStatus.failed => const _StatusPresentation(
      label: 'FAILED',
      message: 'This payment request previously failed and cannot be confirmed here.',
      color: _error,
      icon: Icons.error_outline_rounded,
    ),
    CustomerPaymentStatus.expired => throw StateError(
      'Expired status is handled before the status switch',
    ),
  };
}

class _ErrorCopy {
  const _ErrorCopy({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

_ErrorCopy _errorCopy(CustomerPaymentPreviewFailure failure) {
  return switch (failure) {
    CustomerPaymentPreviewFailure.unknownReference => const _ErrorCopy(
      title: 'Payment not found',
      message: 'This QR code does not match an available VPay payment. Check with the merchant and scan a new code.',
      icon: Icons.search_off_rounded,
      color: _error,
    ),
    CustomerPaymentPreviewFailure.expired => const _ErrorCopy(
      title: 'Payment expired',
      message: 'This payment request is no longer active. Ask the merchant to generate a new QR code.',
      icon: Icons.schedule_rounded,
      color: _error,
    ),
    CustomerPaymentPreviewFailure.alreadyUsed => const _ErrorCopy(
      title: 'Payment already used',
      message: 'This payment is already processing or completed and cannot be used again.',
      icon: Icons.block_rounded,
      color: _warning,
    ),
    CustomerPaymentPreviewFailure.authentication => const _ErrorCopy(
      title: 'Session verification failed',
      message: 'VPay could not verify your authenticated session. Return and sign in again if retrying does not help.',
      icon: Icons.lock_outline_rounded,
      color: _error,
    ),
    CustomerPaymentPreviewFailure.network => const _ErrorCopy(
      title: 'No network connection',
      message: 'Check your internet connection, then retry this read-only payment lookup.',
      icon: Icons.wifi_off_rounded,
      color: _warning,
    ),
    CustomerPaymentPreviewFailure.timeout => const _ErrorCopy(
      title: 'Request timed out',
      message: 'The payment service took too long to respond. It is safe to try the lookup again.',
      icon: Icons.timer_off_outlined,
      color: _warning,
    ),
    CustomerPaymentPreviewFailure.invalidResponse => const _ErrorCopy(
      title: 'Invalid payment response',
      message: 'VPay received incomplete payment details and cannot safely show this payment.',
      icon: Icons.report_problem_outlined,
      color: _error,
    ),
    CustomerPaymentPreviewFailure.unavailable => const _ErrorCopy(
      title: 'Payment service unavailable',
      message: 'Payment details could not be loaded right now. No payment was attempted.',
      icon: Icons.cloud_off_outlined,
      color: _warning,
    ),
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
