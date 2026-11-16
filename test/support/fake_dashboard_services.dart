import 'package:vpay_mobile/features/card/models/vpay_card.dart';
import 'package:vpay_mobile/features/card/services/card_api_service.dart';
import 'package:vpay_mobile/features/customer/models/customer_transaction.dart';
import 'package:vpay_mobile/features/customer/services/customer_transaction_service.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_balance.dart';
import 'package:vpay_mobile/features/merchant/models/merchant_received_payment.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_balance_service.dart';
import 'package:vpay_mobile/features/merchant/services/merchant_received_payments_service.dart';

/// Widget-test services that never contact Firebase or the backend.
class FakeDashboardCardService extends CardApiService {
  int requests = 0;

  @override
  Future<VPayCard> getCurrentUserCard() async {
    requests++;
    return const VPayCard(
      id: 'test-card',
      maskedNumber: '•••• 1234',
      balance: 1250,
      status: 'ACTIVE',
      expiresAt: null,
      createdAt: null,
    );
  }
}

class FakeDashboardTransactionService implements CustomerTransactionService {
  int requests = 0;

  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async {
    requests++;
    return const [];
  }
}

class FakeDashboardMerchantBalanceService implements MerchantBalanceService {
  @override
  Future<MerchantBalance> getMerchantBalance() async =>
      const MerchantBalance(balanceMinor: 0, currency: 'LKR');
}

class FakeDashboardReceivedPaymentsService
    implements MerchantReceivedPaymentsService {
  @override
  Future<List<MerchantReceivedPayment>> getReceivedPayments({
    int limit = 20,
  }) async => const [];
}
