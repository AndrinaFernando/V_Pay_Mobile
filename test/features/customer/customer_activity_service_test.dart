import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/customer/models/customer_transaction.dart';
import 'package:vpay_mobile/features/customer/services/customer_activity_service.dart';
import 'package:vpay_mobile/features/customer/services/customer_transaction_service.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';
import 'package:vpay_mobile/features/customer_payment/models/customer_payment_preview.dart';

class _Payments implements CustomerTransactionService {
  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async => [
    CustomerTransaction(
      transactionId: 'qr-1',
      paymentReference: 'qr-1',
      merchantName: 'ABC Store',
      amountMinor: 120050,
      currency: 'LKR',
      status: CustomerPaymentStatus.success,
      createdAt: DateTime.utc(2026, 11, 15, 11),
    ),
  ];
}

class _TopUps implements TopUpService {
  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();
  @override
  Future<TopUp> get(String id) => throw UnimplementedError();
  @override
  Future<List<TopUp>> list() async => [
    TopUp(
      id: 'latest',
      status: 'SUCCESS',
      requestedAmount: 5000,
      amount: 5000,
      createdAt: DateTime.utc(2026, 11, 15, 12),
    ),
    TopUp(
      id: 'failed',
      status: 'FAILED',
      requestedAmount: 1000,
      createdAt: DateTime.utc(2026, 11, 15, 10),
    ),
    const TopUp(id: 'pending', status: 'PENDING', requestedAmount: 2000),
  ];
}

class _FailedPayments implements CustomerTransactionService {
  @override
  Future<List<CustomerTransaction>> getTransactions({int limit = 50}) async =>
      throw StateError('payment API offline');
}

class _FailedTopUps implements TopUpService {
  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();
  @override
  Future<TopUp> get(String id) => throw UnimplementedError();
  @override
  Future<List<TopUp>> list() async => throw StateError('top-up API offline');
}

void main() {
  test(
    'keeps top-ups when QR history fails and marks history incomplete',
    () async {
      final items =
          await CustomerActivityService(
                payments: _FailedPayments(),
                topUps: _TopUps(),
              ).getTransactions()
              as CustomerActivityList;
      expect(items.paymentsUnavailable, isTrue);
      expect(items.topUpsUnavailable, isFalse);
      expect(items.warning, contains('QR payment history'));
      expect(items.map((item) => item.transactionId), [
        'topup-latest',
        'topup-failed',
        'topup-pending',
      ]);
      expect(items.first.amountMinor, 500000);
    },
  );

  test(
    'keeps QR history when top-ups fail and marks history incomplete',
    () async {
      final items =
          await CustomerActivityService(
                payments: _Payments(),
                topUps: _FailedTopUps(),
              ).getTransactions()
              as CustomerActivityList;
      expect(items.topUpsUnavailable, isTrue);
      expect(items.paymentsUnavailable, isFalse);
      expect(items.warning, contains('Top-up history'));
      expect(items.single.transactionId, 'qr-1');
      expect(items.single.amountMinor, 120050);
    },
  );

  test('reports an error when neither history source succeeds', () async {
    await expectLater(
      CustomerActivityService(
        payments: _FailedPayments(),
        topUps: _FailedTopUps(),
      ).getTransactions(),
      throwsStateError,
    );
  });
  test(
    'combines histories newest first and leaves undated records last',
    () async {
      final items = await CustomerActivityService(
        payments: _Payments(),
        topUps: _TopUps(),
      ).getTransactions();
      expect(items.map((item) => item.transactionId), [
        'topup-latest',
        'qr-1',
        'topup-failed',
        'topup-pending',
      ]);
      expect(items[0].amountMinor, 500000);
      expect(items[0].isTopUp, true);
      expect(items[1].amountMinor, 120050);
      expect(items[1].isTopUp, false);
      expect(items[2].statusLabel, 'FAILED');
      expect(items[3].createdAt, isNull);
      expect(items[3].statusLabel, 'PENDING');
    },
  );
}
