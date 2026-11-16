import 'package:flutter/material.dart';

import '../../customer_payment/models/customer_payment_preview.dart';
import '../models/customer_transaction.dart';

const _ink = Color(0xFF222222);
const _secondary = Color(0xFF767676);
const _divider = Color(0xFFEBEBEB);
const _success = Color(0xFF059669);
const _warning = Color(0xFFD97706);
const _error = Color(0xFFDC2626);

class CustomerTransactionTile extends StatelessWidget {
  const CustomerTransactionTile({
    super.key,
    required this.transaction,
    this.compact = false,
  });

  final CustomerTransaction transaction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transaction.status) {
      CustomerPaymentStatus.success => _success,
      CustomerPaymentStatus.failed || CustomerPaymentStatus.expired => _error,
      _ => _warning,
    };

    return Container(
      key: ValueKey('customerTransaction-${transaction.transactionId}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 13 : 16,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(transaction.createdAt.toLocal()),
                  style: const TextStyle(color: _secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatLkrMinor(transaction.amountMinor),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transaction.status.apiValue,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = (value.hour % 12 == 0 ? 12 : value.hour % 12).toString().padLeft(
    2,
    '0',
  );
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$day/$month/${value.year}  $hour:$minute $period';
}
