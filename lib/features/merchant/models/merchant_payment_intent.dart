class MerchantPaymentIntent {
  const MerchantPaymentIntent({
    required this.paymentReference,
    required this.merchantName,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.description,
    this.paidAt,
  });

  final String paymentReference;
  final String merchantName;
  final int amountMinor;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? description;
  final DateTime? paidAt;

  String get qrPayload => paymentReference;

  factory MerchantPaymentIntent.fromJson(Map<String, dynamic> json) {
    final amountMinor = json['amountMinor'];
    final createdAt = _parseDate(json['createdAt']);
    final expiresAt = _parseDate(json['expiresAt']);
    final paidAt = json['paidAt'] == null ? null : _parseDate(json['paidAt']);

    if (json['paymentReference'] is! String ||
        (json['paymentReference'] as String).trim().isEmpty ||
        json['merchantName'] is! String ||
        (json['merchantName'] as String).trim().isEmpty ||
        amountMinor is! int ||
        amountMinor <= 0 ||
        json['currency'] is! String ||
        json['status'] is! String ||
        createdAt == null ||
        expiresAt == null ||
        (json['paidAt'] != null && paidAt == null) ||
        (json['description'] != null && json['description'] is! String)) {
      throw const FormatException('Invalid payment intent response');
    }

    return MerchantPaymentIntent(
      paymentReference: json['paymentReference'] as String,
      merchantName: json['merchantName'] as String,
      amountMinor: amountMinor,
      currency: json['currency'] as String,
      // Legacy compatibility only: the agreed API status is SUCCESS.
      // Convert older COMPLETED responses for display; never send COMPLETED
      // as a request status or treat a local event as payment confirmation.
      status: (json['status'] as String) == 'COMPLETED'
          ? 'SUCCESS'
          : json['status'] as String,
      createdAt: createdAt,
      expiresAt: expiresAt,
      description: json['description'] as String?,
      paidAt: paidAt,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
