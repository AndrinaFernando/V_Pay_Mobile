/// Merchant-side amount policy for creating LKR payment requests.
///
/// The default mirrors the backend's authoritative limit. A future
/// merchant-specific policy can be supplied when the backend exposes
/// approved limits for that merchant.
class PaymentAmountLimits {
  const PaymentAmountLimits({
    required this.minimumMinor,
    required this.maximumMinor,
  });

  static const lkrDefault = PaymentAmountLimits(
    minimumMinor: 1000,
    maximumMinor: 10000000,
  );

  final int minimumMinor;
  final int maximumMinor;

  bool accepts(int amountMinor) =>
      amountMinor >= minimumMinor && amountMinor <= maximumMinor;

  String get displayRange =>
      'LKR ${_format(minimumMinor)}–LKR ${_format(maximumMinor)}';

  static String _format(int minor) {
    final rupees = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    final grouped = rupees.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$grouped.$cents';
  }
}
