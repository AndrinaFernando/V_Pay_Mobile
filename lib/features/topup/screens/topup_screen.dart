import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../services/topup_service.dart';
import 'rupio_checkout_screen.dart';
import 'topup_history_screen.dart';

const _blue = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _invalidAmount =
    'Invalid amount. Enter a whole number from Rs. 1 to Rs. 1,000,000.';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({
    super.key,
    this.service,
    this.openCheckout,
    this.checkoutBuilder,
  });
  final TopUpService? service;
  final Future<bool> Function(Uri)? openCheckout;
  final Widget Function(Uri, String, TopUpService)? checkoutBuilder;
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen>
    with SingleTickerProviderStateMixin {
  final _amount = TextEditingController();
  late final TopUpService _service;
  late final AnimationController _loadingAnimation;
  TopUp? _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ApiTopUpService();
    _loadingAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _loadingAnimation.dispose();
    _amount.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is StateError &&
        error.message == 'No authenticated Firebase user') {
      return 'Please sign in again to top up.';
    }
    if (error is ApiException) {
      if (error.statusCode == 401) return 'Please sign in again to top up.';
      if (error.statusCode == 403) {
        if (error.message == 'Email verification is required.') {
          return 'Please verify your email before topping up.';
        }
        return 'Your account can’t make a top-up right now. Please contact support.';
      }
      if (error.statusCode == 400) return _invalidAmount;
    }
    return 'We couldn’t confirm if your top-up started. Check Top-up history before trying again.';
  }

  Future<void> _openUrl(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(
        () => _error =
            'Couldn’t open checkout. Check Top-up history before trying again.',
      );
      return;
    }
    try {
      if (widget.openCheckout != null) {
        final opened = await widget.openCheckout!(uri);
        if (!opened && mounted) {
          setState(
            () => _error = 'Couldn’t open checkout. Check Top-up history before trying again.',
          );
        }
        return;
      }
      final selected = _selected;
      if (selected == null) return;
      final result = await Navigator.of(context).push<TopUp>(
        MaterialPageRoute(
          builder: (_) =>
              widget.checkoutBuilder?.call(uri, selected.id, _service) ??
              RupioCheckoutScreen(
                url: uri,
                topUpId: selected.id,
                service: _service,
              ),
        ),
      );
      if (!mounted) return;
      if (result != null && !result.isPending) {
        Navigator.of(context).pop(_status(result));
      } else {
        setState(() => _selected = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t open checkout. Check Top-up history before trying again.',
        );
      }
    }
  }

  Future<void> _start() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < 1 || amount > 1000000) {
      setState(() => _error = _invalidAmount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _loadingAnimation.repeat();
    try {
      final result = await _service.create(amount);
      if (!mounted) return;
      setState(() {
        _selected = result;
      });
      await _openUrl(result.checkoutUrl);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _selected = null;
        });
      }
    } finally {
      if (mounted) {
        _loadingAnimation.stop();
        _loadingAnimation.reset();
        setState(() => _busy = false);
      }
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

  Future<void> _showHistory() async {
    final selected = await Navigator.of(context).push<TopUp>(
      MaterialPageRoute(builder: (_) => TopUpHistoryScreen(service: _service)),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selected = selected;
      _error = null;
    });
    await _openUrl(selected.checkoutUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Top Up',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(6),
          child: ColoredBox(
            color: Color(0xFFF0F0F0),
            child: SizedBox(height: 6, width: double.infinity),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showHistory,
                        icon: const Icon(Icons.history, size: 20),
                        label: const Text('Top-up history'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    onChanged: (_) {
                      if (_error == _invalidAmount)
                        setState(() => _error = null);
                    },
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 20, color: _ink),
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixText: 'Rs. ',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _blue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add money to your VPay card in whole rupees.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _busy ? null : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: const Color(0xFF005DB8),
                    disabledForegroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_busy)
                          AnimatedBuilder(
                            animation: _loadingAnimation,
                            builder: (context, child) => Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _loadingAnimation.value,
                                heightFactor: 1,
                                child: child,
                              ),
                            ),
                            child: const ColoredBox(color: Color(0x6627BAFF)),
                          ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_busy) ...[
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                _busy
                                    ? 'Starting checkout...'
                                    : 'Continue to Rupio',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
