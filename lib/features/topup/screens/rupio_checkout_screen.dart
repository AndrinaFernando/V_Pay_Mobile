import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/topup_service.dart';

/// Displays Rupio's hosted checkout. Only the backend can confirm a result.
class RupioCheckoutScreen extends StatefulWidget {
  const RupioCheckoutScreen({
    super.key,
    required this.url,
    required this.topUpId,
    required this.service,
  });
  final Uri url;
  final String topUpId;
  final TopUpService service;

  @override
  State<RupioCheckoutScreen> createState() => _RupioCheckoutScreenState();
}

class _RupioCheckoutScreenState extends State<RupioCheckoutScreen> {
  late final WebViewController _controller;
  Timer? _timer;
  bool _checking = false;
  bool _loading = true;
  bool _returnRequested = false;
  TopUp? _terminalResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'RupioCheckout',
        onMessageReceived: (message) {
          if (message.message != 'return-home') return;
          _returnRequested = true;
          final result = _terminalResult;
          if (result != null && mounted) {
            Navigator.of(context).pop(result);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final destination = Uri.tryParse(request.url);
            return destination != null &&
                    destination.scheme == 'https' &&
                    destination.host == widget.url.host &&
                    destination.port == widget.url.port
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _loading = false;
                _error = 'Could not load checkout. Check your connection and try again.';
              });
            }
          },
        ),
      )
      ..loadRequest(widget.url);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _checkStatus);
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await widget.service.get(widget.topUpId);
      if (!mounted) return;
      if (const {
        'SUCCESS',
        'FAILED',
        'CANCELLED',
        'TIMEOUT',
      }.contains(result.status)) {
        _terminalResult = result;
        if (mounted) setState(() {});
        _timer?.cancel();
        if (_returnRequested && mounted) {
          Navigator.of(context).pop(result);
        }
        return;
      }
    } catch (_) {
      // Keep checkout available and retry; network errors are not payment results.
    } finally {
      _checking = false;
      if (mounted && _terminalResult == null) _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rupio checkout')),
    body: SafeArea(
      child: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => _controller.loadRequest(widget.url),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
          if (_terminalResult != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Payment status is ready. Tap Return to Home in Rupio to finish.',
              ),
            ),
        ],
      ),
    ),
  );
}
