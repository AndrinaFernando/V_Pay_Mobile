import 'package:flutter/material.dart';

import '../models/customer_transaction.dart';
import '../widgets/customer_transaction_tile.dart';

const _electric = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _secondary = Color(0xFF767676);
const _surface = Color(0xFFF7F7F7);

class CustomerActivityScreen extends StatelessWidget {
  const CustomerActivityScreen({
    super.key,
    required this.transactionsFuture,
    required this.onRefresh,
  });

  final Future<List<CustomerTransaction>> transactionsFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Text(
            'Activity',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerTransaction>>(
            future: transactionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: _electric),
                );
              }

              if (snapshot.hasError) {
                return _ActivityMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load activity',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: onRefresh,
                );
              }

              final transactions = snapshot.data ?? const [];
              if (transactions.isEmpty) {
                return RefreshIndicator(
                  key: const ValueKey('customerActivityRefreshIndicator'),
                  onRefresh: onRefresh,
                  color: _electric,
                  child: const CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ActivityMessage(
                          icon: Icons.receipt_long_outlined,
                          title: 'No payment activity yet',
                          message: 'QR payments and top-ups will appear here.',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                key: const ValueKey('customerActivityRefreshIndicator'),
                onRefresh: onRefresh,
                color: _electric,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) => Material(
                    color: _surface,
                    borderRadius: index == 0
                        ? const BorderRadius.vertical(top: Radius.circular(18))
                        : index == transactions.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          )
                        : BorderRadius.zero,
                    clipBehavior: Clip.antiAlias,
                    child: CustomerTransactionTile(
                      transaction: transactions[index],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _electric),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _secondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('retryCustomerActivityButton'),
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
