import 'package:flutter/material.dart';

import '../models/merchant_received_payment.dart';

const _ink = Color(0xFF1B1C1C);
const _supporting = Color(0xFF5A606D);
const _divider = Color(0xFFDBE0EC);
const _success = Color(0xFF059669);

class MerchantReceivedPaymentTile extends StatelessWidget {
  const MerchantReceivedPaymentTile({
    super.key,
    required this.payment,
    this.compact = false,
  });

  final MerchantReceivedPayment payment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final date = _formatDateTime(payment.createdAt.toLocal());
    return Container(
      key: ValueKey('merchantReceivedPayment-${payment.transactionId}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 14 : 17,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.south_west_rounded,
              color: _success,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment received',
                  style: TextStyle(
                    color: _ink,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ref: ${payment.paymentReference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _supporting, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: _supporting, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMerchantLkrMinor(payment.amountMinor),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: _ink,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SUCCESS',
                  style: TextStyle(
                    color: _success,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
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
