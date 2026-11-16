import 'dart:collection';

import '../../topup/services/topup_service.dart';
import '../models/customer_transaction.dart';
import 'customer_transaction_service.dart';

/// Carries completeness alongside the familiar list used by both screens.
class CustomerActivityList extends ListBase<CustomerTransaction> {
  CustomerActivityList(
    this._items, {
    required this.paymentsUnavailable,
    required this.topUpsUnavailable,
  });

  final List<CustomerTransaction> _items;
  final bool paymentsUnavailable;
  final bool topUpsUnavailable;
  bool get isPartial => paymentsUnavailable || topUpsUnavailable;
  String get warning => paymentsUnavailable
      ? 'QR payment history is unavailable. Activity may be incomplete.'
      : 'Top-up history is unavailable. Activity may be incomplete.';

  @override
  int get length => _items.length;
  @override
  set length(int value) => throw UnsupportedError('Activity is read-only');
  @override
  CustomerTransaction operator [](int index) => _items[index];
  @override
  void operator []=(int index, CustomerTransaction value) =>
      throw UnsupportedError('Activity is read-only');
}

/// Reads the two existing histories without changing either financial API.
class CustomerActivityService implements CustomerTransactionService {
  CustomerActivityService({required this.payments, required this.topUps});

  final CustomerTransactionService payments;
  final TopUpService topUps;

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async {
    // Start both reads independently. A failed source must not hide the other.
    final paymentRequest =
        Future.sync(() => payments.getTransactions(limit: limit))
            .then<List<CustomerTransaction>?>(
              (items) => items,
              onError: (Object _) => null,
            );
    final topUpRequest = Future.sync(topUps.list)
        .then<List<TopUp>?>((items) => items, onError: (Object _) => null);
    final paymentItems = await paymentRequest;
    final topUpItems = await topUpRequest;
    if (paymentItems == null && topUpItems == null) {
      throw StateError('Both activity sources are unavailable');
    }
    final activity = <CustomerTransaction>[
      ...?paymentItems,
      for (final item in topUpItems ?? const <TopUp>[])
        CustomerTransaction.fromTopUp(item),
    ];
    activity.sort((left, right) {
      final a = left.createdAt;
      final b = right.createdAt;
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });
    return CustomerActivityList(
      activity,
      paymentsUnavailable: paymentItems == null,
      topUpsUnavailable: topUpItems == null,
    );
  }
}
