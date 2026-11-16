class MerchantReceivedPayment {
  const MerchantReceivedPayment({
    required this.transactionId,
    required this.paymentReference,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  final String transactionId;
  final String paymentReference;
  final int amountMinor;
  final String currency;
  final String status;
  final DateTime createdAt;

  factory MerchantReceivedPayment.fromJson(Map<String, dynamic> json) {
    final transactionId = _requiredText(
      json['transactionId'],
      'transaction ID',
    );
    final paymentReference = _requiredText(
      json['paymentReference'],
      'payment reference',
    );
    final amountMinor = json['amountMinor'];
    if (amountMinor is! int ||
        amountMinor <= 0 ||
        amountMinor > 9007199254740991) {
      throw const FormatException('Invalid transaction amount');
    }

    final currency = _requiredText(json['currency'], 'currency');
    if (currency != 'LKR') {
      throw const FormatException('Unsupported transaction currency');
    }
    if (json['status'] != 'SUCCESS') {
      throw const FormatException('Transaction is not a confirmed success');
    }

    final rawCreatedAt = json['createdAt'];
    final createdAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt)
        : null;
    if (createdAt == null) {
      throw const FormatException('Invalid transaction date');
    }

    return MerchantReceivedPayment(
      transactionId: transactionId,
      paymentReference: paymentReference,
      amountMinor: amountMinor,
      currency: currency,
      status: 'SUCCESS',
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

String formatMerchantLkrMinor(int amountMinor) {
  final whole = amountMinor ~/ 100;
  final cents = (amountMinor % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return 'LKR $buffer.$cents';
}
