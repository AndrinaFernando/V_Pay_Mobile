import 'package:flutter/material.dart';

import '../../../core/security/local_auth_service.dart';
import '../models/customer_payment_preview.dart';
import '../models/customer_payment_result.dart';
import '../services/customer_payment_confirmation_service.dart';
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
    this.confirmationService,
    this.localAuthService,
    this.onPaymentSuccess,
  });

  final String paymentReference;
  final CustomerPaymentPreviewService? previewService;
  final CustomerPaymentConfirmationService? confirmationService;
  final LocalAuthService? localAuthService;
  final ValueChanged<CustomerPaymentResult>? onPaymentSuccess;

  @override
  State<CustomerPaymentPreviewScreen> createState() =>
      _CustomerPaymentPreviewScreenState();
}

class _CustomerPaymentPreviewScreenState
    extends State<CustomerPaymentPreviewScreen> {
  late final CustomerPaymentPreviewService _previewService;
  CustomerPaymentConfirmationService? _confirmationService;
  late final LocalAuthService _localAuthService;
  CustomerPaymentPreview? _preview;
  CustomerPaymentPreviewFailure? _failure;
  CustomerPaymentResult? _paymentResult;
  String? _confirmationMessage;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _isCheckingStatus = false;
  bool _isPaymentResultUnknown = false;
  bool _didNotifyPaymentSuccess = false;
  String? _unknownResultMessage;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _previewService =
        widget.previewService ?? ApiCustomerPaymentPreviewService();
    _confirmationService = widget.confirmationService;
    _localAuthService = widget.localAuthService ?? LocalAuthService();
    _loadPreview();
  }

  Future<void> _confirmPayment() async {
    if (_isConfirming || _isCheckingStatus) return;
    final preview = _preview;
    if (preview == null ||
        preview.status != CustomerPaymentStatus.pending ||
        preview.isExpiredAt(DateTime.now())) {
      return;
    }

    setState(() {
      _isConfirming = true;
      _confirmationMessage = null;
    });

    var authenticated = false;
    try {
      authenticated = await _localAuthService.authenticateForSensitiveAction(
        reason:
            'Authenticate to pay ${formatLkrMinor(preview.amountMinor)} to ${preview.merchantName}',
      );
    } catch (_) {
      authenticated = false;
    }

    if (!mounted) return;
    if (!authenticated) {
      setState(() {
        _isConfirming = false;
        _confirmationMessage = 'Device authentication was cancelled or could not be completed. No payment was submitted.';
      });
      return;
    }

    try {
      final result = await _paymentConfirmationService.confirmPayment(
        widget.paymentReference,
      );
      if (!mounted) return;
      if (!result.matchesApprovedPreview(preview)) {
        await _checkPaymentStatus(afterInconsistentReceipt: true);
        return;
      }
      _acceptVerifiedPaymentResult(result);
    } on CustomerPaymentConfirmationException catch (error) {
      if (!mounted) return;
      if (error.failure ==
              CustomerPaymentConfirmationFailure.ambiguousNetwork ||
          error.failure == CustomerPaymentConfirmationFailure.invalidResponse) {
        await _checkPaymentStatus(afterAmbiguousConfirmation: true);
        return;
      }
      setState(() {
        _isConfirming = false;
        _confirmationMessage = _confirmationFailureMessage(error.failure);
      });
    } catch (_) {
      if (!mounted) return;
      await _checkPaymentStatus(afterAmbiguousConfirmation: true);
    }
  }

  Future<void> _checkPaymentStatus({
    bool afterAmbiguousConfirmation = false,
    bool afterInconsistentReceipt = false,
  }) async {
    if (_isCheckingStatus) return;
    setState(() {
      _isCheckingStatus = true;
      _isPaymentResultUnknown = false;
      _unknownResultMessage = null;
      if (afterAmbiguousConfirmation) {
        _confirmationMessage = 'The confirmation response was interrupted. Checking payment status without resubmitting…';
      } else if (afterInconsistentReceipt) {
        _confirmationMessage = 'The receipt did not match the payment you approved. Checking the authoritative payment status…';
      }
    });

    try {
      final result = await _paymentConfirmationService.getPaymentStatus(
        widget.paymentReference,
      );
      if (!mounted) return;
      final preview = _preview;
      if (result.status == CustomerPaymentStatus.success &&
          (preview == null || !result.matchesApprovedPreview(preview))) {
        setState(() {
          _paymentResult = null;
          _isConfirming = false;
          _isCheckingStatus = false;
          _isPaymentResultUnknown = true;
          _unknownResultMessage = 'VPay returned payment details that do not match the payment you approved. Do not confirm again. Contact support with the payment reference.';
          _confirmationMessage = null;
        });
        return;
      }
      if (result.status == CustomerPaymentStatus.success) {
        _acceptVerifiedPaymentResult(result);
        return;
      }
      setState(() {
        _paymentResult = result;
        _isConfirming = false;
        _isCheckingStatus = false;
        _confirmationMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentResult = null;
        _isConfirming = false;
        _isCheckingStatus = false;
        _isPaymentResultUnknown = true;
        _unknownResultMessage = 'VPay could not determine the final result. Do not confirm again; check the payment status when connectivity returns.';
        _confirmationMessage = null;
      });
    }
  }

  void _acceptVerifiedPaymentResult(CustomerPaymentResult result) {
    setState(() {
      _paymentResult = result;
      _isConfirming = false;
      _isCheckingStatus = false;
      _isPaymentResultUnknown = false;
      _unknownResultMessage = null;
      _confirmationMessage = null;
    });

    if (_didNotifyPaymentSuccess) return;
    _didNotifyPaymentSuccess = true;
    widget.onPaymentSuccess?.call(result);
  }

  CustomerPaymentConfirmationService get _paymentConfirmationService {
    return _confirmationService ??= ApiCustomerPaymentConfirmationService();
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
    final paymentResult = _paymentResult;
    if (paymentResult != null || _isPaymentResultUnknown) {
      return _PaymentResolutionView(
        key: const ValueKey('paymentResolution'),
        result: paymentResult,
        isUnknown: _isPaymentResultUnknown,
        unknownMessage: _unknownResultMessage,
        isCheckingStatus: _isCheckingStatus,
        onCheckStatus: () => _checkPaymentStatus(),
        onDone: () => Navigator.of(context).pop(),
      );
    }

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
      isConfirming: _isConfirming,
      isCheckingStatus: _isCheckingStatus,
      confirmationMessage: _confirmationMessage,
      onConfirm: _confirmPayment,
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
    required this.isConfirming,
    required this.isCheckingStatus,
    required this.confirmationMessage,
    required this.onConfirm,
  });

  final String paymentReference;
  final CustomerPaymentPreview preview;
  final bool isConfirming;
  final bool isCheckingStatus;
  final String? confirmationMessage;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(preview, DateTime.now());
    final canConfirm =
        preview.status == CustomerPaymentStatus.pending &&
        !preview.isExpiredAt(DateTime.now());
    final isBusy = isConfirming || isCheckingStatus;

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
              if (confirmationMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('paymentConfirmationMessage'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _warning.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    confirmationMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('confirmPaymentButton'),
                  onPressed: canConfirm && !isBusy ? onConfirm : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _electric,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _divider,
                    disabledForegroundColor: _secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _secondary,
                          ),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    isCheckingStatus
                        ? 'Checking payment status…'
                        : isConfirming
                        ? 'Confirming securely…'
                        : canConfirm
                        ? 'Confirm Payment'
                        : 'Payment confirmation unavailable',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                canConfirm
                    ? 'You will authenticate on this device before VPay submits the payment reference.'
                    : 'No new payment can be submitted for this payment request.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentResolutionView extends StatelessWidget {
  const _PaymentResolutionView({
    super.key,
    required this.result,
    required this.isUnknown,
    required this.unknownMessage,
    required this.isCheckingStatus,
    required this.onCheckStatus,
    required this.onDone,
  });

  final CustomerPaymentResult? result;
  final bool isUnknown;
  final String? unknownMessage;
  final bool isCheckingStatus;
  final VoidCallback onCheckStatus;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final status = result?.status;
    final isSuccess = status == CustomerPaymentStatus.success;
    final canCheckAgain =
        isUnknown ||
        status == CustomerPaymentStatus.pending ||
        status == CustomerPaymentStatus.processing;
    final title = switch (status) {
      CustomerPaymentStatus.success => 'Payment successful',
      CustomerPaymentStatus.pending => 'Payment still pending',
      CustomerPaymentStatus.processing => 'Payment processing',
      CustomerPaymentStatus.failed => 'Payment failed',
      CustomerPaymentStatus.expired => 'Payment expired',
      null => 'Payment result unknown',
    };
    final message = switch (status) {
      CustomerPaymentStatus.success =>
        'VPay confirmed the payment and verified the server receipt.',
      CustomerPaymentStatus.pending => 'VPay reports that this payment is still pending. The confirmation request was not resubmitted.',
      CustomerPaymentStatus.processing => 'VPay is processing this payment. Do not submit it again; check the status instead.',
      CustomerPaymentStatus.failed => 'VPay reports that this payment failed. No successful receipt is available.',
      CustomerPaymentStatus.expired =>
        'This payment request expired without a successful receipt.',
      null => unknownMessage ?? 'VPay could not determine the final result. Do not confirm again; check the status when connectivity returns.',
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : isUnknown
                    ? Icons.help_outline_rounded
                    : Icons.info_outline_rounded,
                color: isSuccess ? _success : _warning,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (isSuccess) ...[
                const SizedBox(height: 24),
                _PaymentReceiptCard(result: result!),
              ],
              if (canCheckAgain) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const ValueKey('checkPaymentStatusButton'),
                  onPressed: isCheckingStatus ? null : onCheckStatus,
                  icon: isCheckingStatus
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    isCheckingStatus
                        ? 'Checking status…'
                        : 'Check Status Again',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('finishPaymentButton'),
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: _electric,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentReceiptCard extends StatelessWidget {
  const _PaymentReceiptCard({required this.result});

  final CustomerPaymentResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Merchant', value: result.merchantName!),
          _DetailRow(
            label: 'Amount',
            value: formatLkrMinor(result.amountMinor!),
          ),
          _DetailRow(label: 'Transaction ID', value: result.transactionId!),
          _DetailRow(
            label: 'Paid at',
            value: _formatDateTime(result.paidAt!),
            showDivider: false,
          ),
        ],
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
      message: 'Review these verified details, then select Confirm Payment to continue.',
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
    CustomerPaymentPreviewFailure.customerProfileNotFound => const _ErrorCopy(
      title: 'Customer profile not found',
      message: 'VPay could not find your Customer profile. Complete your account setup, then try again, or contact VPay support if you need help.',
      icon: Icons.person_search_outlined,
      color: _warning,
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
    CustomerPaymentPreviewFailure.accountNotReady => const _ErrorCopy(
      title: 'QR payments unavailable',
      message: 'Your account cannot currently access QR payment previews. Make sure your email is verified and your Customer account is active, then try again.',
      icon: Icons.person_off_outlined,
      color: _warning,
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

String _confirmationFailureMessage(CustomerPaymentConfirmationFailure failure) {
  return switch (failure) {
    CustomerPaymentConfirmationFailure.authentication =>
      'Your VPay session could not be verified. Sign in again before retrying.',
    CustomerPaymentConfirmationFailure.notFound =>
      'This payment request was not found. No payment was completed.',
    CustomerPaymentConfirmationFailure.expired =>
      'This payment request has expired. Ask the merchant for a new QR code.',
    CustomerPaymentConfirmationFailure.failed =>
      'This payment request previously failed and cannot be retried.',
    CustomerPaymentConfirmationFailure.alreadyPaid =>
      'This QR payment has already been paid by another customer.',
    CustomerPaymentConfirmationFailure.belowMinimum =>
      'The payment amount is below VPay’s minimum QR payment amount.',
    CustomerPaymentConfirmationFailure.limitExceeded =>
      'This payment exceeds your allowed QR transaction limit.',
    CustomerPaymentConfirmationFailure.insufficientBalance =>
      'Your card does not have enough funds for this payment.',
    CustomerPaymentConfirmationFailure.minimumBalanceRequired => 'This payment would reduce your card below the required Rs. 500 retained balance.',
    CustomerPaymentConfirmationFailure.cardFrozen =>
      'Your VPay card is frozen and cannot make this payment.',
    CustomerPaymentConfirmationFailure.cardExpired =>
      'Your VPay card has expired and cannot make this payment.',
    CustomerPaymentConfirmationFailure.accountNotReady =>
      'Your customer account is not ready to make payments.',
    CustomerPaymentConfirmationFailure.merchantUnavailable =>
      'The merchant cannot receive this payment right now.',
    CustomerPaymentConfirmationFailure.balanceSchema =>
      'Your payment balance requires support before QR payments can continue.',
    CustomerPaymentConfirmationFailure.conflict =>
      'VPay found an inconsistent payment state. No new payment was submitted.',
    CustomerPaymentConfirmationFailure.unavailable =>
      'QR payment execution is unavailable right now. Please try again later.',
    CustomerPaymentConfirmationFailure.ambiguousNetwork => 'The payment result could not be determined. Check its status instead of confirming again.',
    CustomerPaymentConfirmationFailure.invalidResponse =>
      'VPay received an invalid payment response and cannot confirm success.',
  };
}
