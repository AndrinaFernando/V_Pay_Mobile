import 'package:flutter/material.dart';

import '../services/topup_service.dart';

class TopUpHistoryScreen extends StatefulWidget {
  const TopUpHistoryScreen({super.key, required this.service});
  final TopUpService service;

  @override
  State<TopUpHistoryScreen> createState() => _TopUpHistoryScreenState();
}

class _TopUpHistoryScreenState extends State<TopUpHistoryScreen> {
  late Future<List<TopUp>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.service.list();
  }

  String _status(String status) => switch (status) {
    'SUCCESS' => 'Top-up successful',
    'FAILED' => 'Payment declined',
    'CANCELLED' => 'Payment cancelled',
    'TIMEOUT' => 'Payment timed out',
    'START_FAILED' => 'Checkout could not start',
    'START_UNKNOWN' => 'Checkout status unknown',
    _ => 'Waiting for payment confirmation',
  };

  Future<void> _details(TopUp item) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_status(item.status)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requested: Rs. ${item.requestedAmount}'),
            if (item.amount != null) Text('Final amount: Rs. ${item.amount}'),
            const SizedBox(height: 8),
            SelectableText('Reference: ${item.id}'),
            if (item.message != null) ...[
              const SizedBox(height: 8),
              Text(item.message!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          if (item.isPending && item.checkoutUrl != null)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open checkout'),
            ),
        ],
      ),
    );
    if (open == true && mounted) Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Top-up history'),
      backgroundColor: Colors.white,
    ),
    body: FutureBuilder<List<TopUp>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load top-up history.'),
                TextButton(
                  onPressed: () => setState(() {
                    _history = widget.service.list();
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No top-ups yet.'));
        return RefreshIndicator(
          onRefresh: () async {
            final future = widget.service.list();
            setState(() {
              _history = future;
            });
            try {
              await future;
            } catch (_) {}
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF4FF),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF0072DC),
                  ),
                ),
                title: Text(_status(item.status)),
                subtitle: Text(
                  'Reference: ${item.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  'Rs. ${item.amount ?? item.requestedAmount}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => _details(item),
              );
            },
          ),
        );
      },
    ),
  );
}
