class VPayCard {
  const VPayCard({
    required this.id,
    required this.maskedNumber,
    required this.balance,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String? maskedNumber;
  final num balance;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory VPayCard.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'];
    if (balance is! num) {
      throw const FormatException('Invalid card balance');
    }

    return VPayCard(
      id: json['id'] as String,
      maskedNumber: json['maskedNumber'] as String?,
      balance: balance,
      status: json['status'] as String,
      expiresAt: _parseDate(json['expiresAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
