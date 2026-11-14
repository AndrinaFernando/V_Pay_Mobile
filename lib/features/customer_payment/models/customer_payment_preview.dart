enum CustomerPaymentStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  success('SUCCESS'),
  failed('FAILED'),
  expired('EXPIRED');

  const CustomerPaymentStatus(this.apiValue);

  final String apiValue;

  static CustomerPaymentStatus parse(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid payment status');
    }

    return CustomerPaymentStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw const FormatException('Invalid payment status'),
    );
  }
}

class CustomerPaymentPreview {
  const CustomerPaymentPreview({
    required this.merchantUid,
    required this.merchantName,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.description,
    this.paidAt,
  });

  final String merchantUid;
  final String merchantName;
  final int amountMinor;
  final String currency;
  final CustomerPaymentStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? description;
  final DateTime? paidAt;

  factory CustomerPaymentPreview.fromJson(Map<String, dynamic> json) {
    final merchantUid = _requiredText(json['merchantUid'], 'merchant UID');
    final merchantName = _requiredText(json['merchantName'], 'merchant name');
    final amountMinor = json['amountMinor'];
    if (amountMinor is! int || amountMinor < 0) {
      throw const FormatException('Invalid payment amount');
    }

    final currency = _requiredText(json['currency'], 'currency');
    if (currency != 'LKR') {
      throw const FormatException('Unsupported payment currency');
    }

    final description = json['description'];
    if (description != null && description is! String) {
      throw const FormatException('Invalid payment description');
    }

    return CustomerPaymentPreview(
      merchantUid: merchantUid,
      merchantName: merchantName,
      amountMinor: amountMinor,
      currency: currency,
      status: CustomerPaymentStatus.parse(json['status']),
      createdAt: _requiredDate(json['createdAt'], 'creation date'),
      expiresAt: _requiredDate(json['expiresAt'], 'expiry date'),
      description: description is String && description.trim().isNotEmpty
          ? description.trim()
          : null,
      paidAt: _optionalDate(json['paidAt'], 'paid date'),
    );
  }

  bool isExpiredAt(DateTime time) =>
      status == CustomerPaymentStatus.expired ||
      (status == CustomerPaymentStatus.pending && !expiresAt.isAfter(time));

  static String _requiredText(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $field');
    }
    return value.trim();
  }

  static DateTime _requiredDate(Object? value, String field) {
    final parsed = _optionalDate(value, field);
    if (parsed == null) throw FormatException('Invalid $field');
    return parsed;
  }

  static DateTime? _optionalDate(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid $field');

    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid $field');
    return parsed;
  }
}

String formatLkrMinor(int amountMinor) {
  final whole = amountMinor ~/ 100;
  final cents = (amountMinor % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }

  return 'Rs. $buffer.$cents';
}
