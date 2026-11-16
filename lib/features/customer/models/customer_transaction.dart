import '../../customer_payment/models/customer_payment_preview.dart';
import '../../topup/services/topup_service.dart';

class CustomerTransaction {
  const CustomerTransaction({
    required this.transactionId,
    required this.paymentReference,
    required this.merchantName,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.isTopUp = false,
    this.statusLabel,
  });

  final String transactionId;
  final String paymentReference;
  final String merchantName;
  final int amountMinor;
  final String currency;
  final CustomerPaymentStatus status;
  final DateTime? createdAt;
  final bool isTopUp;
  final String? statusLabel;

  factory CustomerTransaction.fromTopUp(TopUp topUp) {
    final amount = topUp.status == 'SUCCESS'
        ? (topUp.amount ?? topUp.requestedAmount)
        : topUp.requestedAmount;
    return CustomerTransaction(
      transactionId: 'topup-${topUp.id}',
      paymentReference: topUp.id,
      merchantName: 'Rupio Top-up',
      amountMinor: amount * 100,
      currency: 'LKR',
      status: topUp.status == 'SUCCESS'
          ? CustomerPaymentStatus.success
          : topUp.status == 'FAILED' || topUp.status == 'CANCELLED'
          ? CustomerPaymentStatus.failed
          : topUp.status == 'TIMEOUT'
          ? CustomerPaymentStatus.expired
          : CustomerPaymentStatus.pending,
      statusLabel: topUp.status,
      createdAt: topUp.createdAt,
      isTopUp: true,
    );
  }

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) {
    final amountMinor = json['amountMinor'];
    if (amountMinor is! int || amountMinor <= 0) {
      throw const FormatException('Invalid transaction amount');
    }

    final currency = _requiredText(json['currency'], 'currency');
    if (currency != 'LKR') {
      throw const FormatException('Unsupported transaction currency');
    }

    final createdAtValue = json['createdAt'];
    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)
        : null;
    if (createdAt == null) {
      throw const FormatException('Invalid transaction date');
    }

    return CustomerTransaction(
      transactionId: _requiredText(json['transactionId'], 'transaction ID'),
      paymentReference: _requiredText(
        json['paymentReference'],
        'payment reference',
      ),
      merchantName: _requiredText(json['merchantName'], 'merchant name'),
      amountMinor: amountMinor,
      currency: currency,
      status: CustomerPaymentStatus.parse(json['status']),
      createdAt: createdAt,
    );
  }

  static String _requiredText(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $field');
    }
    return value.trim();
  }
}
