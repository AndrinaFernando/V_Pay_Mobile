const minimumRetainedBalanceMinor = 50000;

enum CustomerPaymentBalanceOutcome {
  allowed,
  invalidAmount,
  invalidBalance,
  insufficientBalance,
  minimumRetainedBalanceRequired,
}

class CustomerPaymentBalanceCheck {
  const CustomerPaymentBalanceCheck({
    required this.outcome,
    this.balanceMinor,
    this.maximumPermissibleAmountMinor,
  });

  final CustomerPaymentBalanceOutcome outcome;
  final int? balanceMinor;
  final int? maximumPermissibleAmountMinor;

  bool get isAllowed => outcome == CustomerPaymentBalanceOutcome.allowed;
}

CustomerPaymentBalanceCheck checkCustomerPaymentBalance({
  required num balance,
  required int amountMinor,
}) {
  if (amountMinor <= 0) {
    return const CustomerPaymentBalanceCheck(
      outcome: CustomerPaymentBalanceOutcome.invalidAmount,
    );
  }

  final balanceAsDouble = balance.toDouble();
  if (!balanceAsDouble.isFinite || balanceAsDouble < 0) {
    return const CustomerPaymentBalanceCheck(
      outcome: CustomerPaymentBalanceOutcome.invalidBalance,
    );
  }

  final scaledBalance = balanceAsDouble * 100;
  final balanceMinor = scaledBalance.round();
  if ((scaledBalance - balanceMinor).abs() > 0.000001) {
    return const CustomerPaymentBalanceCheck(
      outcome: CustomerPaymentBalanceOutcome.invalidBalance,
    );
  }

  final maximum = balanceMinor > minimumRetainedBalanceMinor
      ? balanceMinor - minimumRetainedBalanceMinor
      : 0;
  if (balanceMinor < amountMinor) {
    return CustomerPaymentBalanceCheck(
      outcome: CustomerPaymentBalanceOutcome.insufficientBalance,
      balanceMinor: balanceMinor,
      maximumPermissibleAmountMinor: maximum,
    );
  }
  if (balanceMinor - amountMinor < minimumRetainedBalanceMinor) {
    return CustomerPaymentBalanceCheck(
      outcome: CustomerPaymentBalanceOutcome.minimumRetainedBalanceRequired,
      balanceMinor: balanceMinor,
      maximumPermissibleAmountMinor: maximum,
    );
  }

  return CustomerPaymentBalanceCheck(
    outcome: CustomerPaymentBalanceOutcome.allowed,
    balanceMinor: balanceMinor,
    maximumPermissibleAmountMinor: maximum,
  );
}
