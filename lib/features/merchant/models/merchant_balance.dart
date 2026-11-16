class MerchantBalance {
  const MerchantBalance({required this.balanceMinor, required this.currency});

  final int balanceMinor;
  final String currency;

  String get formattedLkr {
    final rupees = balanceMinor ~/ 100;
    final cents = (balanceMinor % 100).toString().padLeft(2, '0');
    final digits = rupees.toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'LKR $grouped.$cents';
  }
}
