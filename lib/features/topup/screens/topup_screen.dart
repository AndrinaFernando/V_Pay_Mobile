import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../services/topup_service.dart';

const _blue = Color(0xFF0072DC);
const _ink = Color(0xFF222222);

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key, this.service, this.openCheckout});
  final TopUpService? service;
  final Future<bool> Function(Uri)? openCheckout;
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> with WidgetsBindingObserver {
  final _amount = TextEditingController();
  late final TopUpService _service;
  List<TopUp> _history = [];
  TopUp? _selected;
  Timer? _timer;
  bool _busy = false;
  bool _checking = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? ApiTopUpService();
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selected?.isPending == true)
      _checkStatus();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Could not connect. Check your connection and try again.';

  Future<void> _loadHistory() async {
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _history = items;
        _loading = false;
        _selected ??= items.isEmpty ? null : items.first;
      });
      if (_selected?.isPending == true) _checkStatus();
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = _message(error);
        });
    }
  }

  void _scheduleCheck() {
    _timer?.cancel();
    if (_selected?.isPending == true) {
      _timer = Timer(const Duration(seconds: 10), _checkStatus);
    }
  }

  Future<void> _checkStatus() async {
    final id = _selected?.id;
    if (id == null || _checking) return;
    _checking = true;
    try {
      final result = await _service.get(id);
      if (!mounted || _selected?.id != id) return;
      setState(() {
        _selected = result;
        _history = [result, ..._history.where((item) => item.id != result.id)];
        _error = null;
      });
    } catch (error) {
      if (mounted && _selected?.id == id)
        setState(() => _error = _message(error));
    } finally {
      _checking = false;
      if (mounted) _scheduleCheck();
    }
  }

  Future<void> _openUrl(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = 'The checkout link is unavailable.');
      return;
    }
    try {
      final opened =
          await (widget.openCheckout?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && mounted)
        setState(() => _error = 'Could not open checkout. Try again.');
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not open checkout. Try again.');
    }
  }

  Future<void> _start() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < 1 || amount > 1000000) {
      setState(
        () => _error = 'Enter a whole amount from Rs. 1 to Rs. 1,000,000.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.create(amount);
      if (!mounted) return;
      setState(() {
        _selected = result;
        _history = [result, ..._history];
      });
      _scheduleCheck();
      await _openUrl(result.checkoutUrl);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _selected = null;
        });
        await _loadHistory();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _status(TopUp item) => switch (item.status) {
    'SUCCESS' => 'Top-up successful',
    'FAILED' => 'Payment declined',
    'CANCELLED' => 'Payment cancelled',
    'TIMEOUT' => 'Payment timed out',
    'START_FAILED' => 'Checkout could not start',
    'START_UNKNOWN' => 'Checkout status unknown',
    _ => 'Waiting for payment confirmation',
  };

  @override
  Widget build(BuildContext context) {
    final item = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Top Up')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Add money to your VPay card',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a whole amount in Sri Lankan rupees. Rupio will show a simulated checkout.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount (LKR)',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _start,
                style: FilledButton.styleFrom(backgroundColor: _blue),
                child: Text(
                  _busy ? 'Starting checkout...' : 'Continue to Rupio',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (item != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _status(item),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Requested: Rs. ${item.requestedAmount}'),
                      if (item.amount != null)
                        Text('Final amount: Rs. ${item.amount}'),
                      Text('Reference: ${item.id}'),
                      if (item.message != null) ...[
                        const SizedBox(height: 8),
                        Text(item.message!),
                      ],
                      if (item.isPending) ...[
                        const SizedBox(height: 8),
                  const Text(
                    'After checkout, return to VPay. Your balance changes only after VPay confirms the payment.',
                  ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _checkStatus,
                              child: const Text('Check status'),
                            ),
                            if (item.checkoutUrl != null)
                              TextButton(
                                onPressed: () => _openUrl(item.checkoutUrl),
                                child: const Text('Open checkout'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Top-up history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No top-ups yet.'),
              )
            else
              ..._history.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_status(entry)),
                  subtitle: Text(
                    'Rs. ${entry.amount ?? entry.requestedAmount} · ${entry.id}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      _selected = entry;
                      _error = null;
                    });
                    if (entry.isPending) {
                      _checkStatus();
                    } else {
                      _timer?.cancel();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
