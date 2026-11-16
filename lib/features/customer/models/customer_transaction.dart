import '../../customer_payment/models/customer_payment_preview.dart';

class CustomerTransaction {
  const CustomerTransaction({
    required this.transactionId,
    required this.paymentReference,
    required this.merchantName,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  final String transactionId;
  final String paymentReference;
  final String merchantName;
  final int amountMinor;
  final String currency;
  final CustomerPaymentStatus status;
  final DateTime createdAt;

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
