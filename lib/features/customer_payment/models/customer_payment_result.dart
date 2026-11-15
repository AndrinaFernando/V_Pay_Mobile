import 'customer_payment_preview.dart';

class CustomerPaymentResult {
  const CustomerPaymentResult({
    required this.paymentReference,
    required this.status,
    this.transactionId,
    this.merchantName,
    this.amountMinor,
    this.currency,
    this.paidAt,
  });

  final String paymentReference;
  final CustomerPaymentStatus status;
  final String? transactionId;
  final String? merchantName;
  final int? amountMinor;
  final String? currency;
  final DateTime? paidAt;

  bool matchesApprovedPreview(CustomerPaymentPreview preview) {
    return status == CustomerPaymentStatus.success &&
        paymentReference == preview.paymentReference &&
        amountMinor == preview.amountMinor &&
        currency == preview.currency;
  }

  factory CustomerPaymentResult.fromJson(Map<String, dynamic> json) {
    final paymentReference = _requiredText(
      json['paymentReference'],
      'payment reference',
    );
    final status = CustomerPaymentStatus.parse(json['status']);

    if (status != CustomerPaymentStatus.success) {
      return CustomerPaymentResult(
        paymentReference: paymentReference,
        status: status,
      );
    }

    final amountMinor = json['amountMinor'];
    if (amountMinor is! int || amountMinor <= 0) {
      throw const FormatException('Invalid payment amount');
    }
    final currency = _requiredText(json['currency'], 'currency');
    if (currency != 'LKR') {
      throw const FormatException('Unsupported payment currency');
    }
    final paidAtValue = json['paidAt'];
    if (paidAtValue is! String) {
      throw const FormatException('Invalid payment date');
    }
    final paidAt = DateTime.tryParse(paidAtValue);
    if (paidAt == null) throw const FormatException('Invalid payment date');

    return CustomerPaymentResult(
      paymentReference: paymentReference,
      status: status,
      transactionId: _requiredText(json['transactionId'], 'transaction ID'),
      merchantName: _requiredText(json['merchantName'], 'merchant name'),
      amountMinor: amountMinor,
      currency: currency,
      paidAt: paidAt,
    );
  }

  static String _requiredText(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $field');
    }
    return value.trim();
  }
}
