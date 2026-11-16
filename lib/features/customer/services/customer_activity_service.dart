import '../../topup/services/topup_service.dart';
import '../models/customer_transaction.dart';
import 'customer_transaction_service.dart';

/// Reads the two existing histories without changing either financial API.
class CustomerActivityService implements CustomerTransactionService {
  CustomerActivityService({required this.payments, required this.topUps});

  final CustomerTransactionService payments;
  final TopUpService topUps;

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async {
    final results = await Future.wait<Object>([
      payments.getTransactions(limit: limit),
      topUps.list(),
    ]);
    final activity = <CustomerTransaction>[
      ...results[0] as List<CustomerTransaction>,
      for (final item in results[1] as List<TopUp>)
        CustomerTransaction.fromTopUp(item),
    ];
    activity.sort((left, right) {
      final a = left.createdAt;
      final b = right.createdAt;
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });
    return activity;
  }
}
