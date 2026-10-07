import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../card/models/vpay_card.dart';
import '../../card/services/card_api_service.dart';

const _electric = Color(0xFF0072DC);
const _strongBlue = Color(0xFF01397C);
const _deepSpace = Color(0xFF00193C);
const _void = Color(0xFF000815);
const _surface = Color(0xFFF7F7F7);
const _divider = Color(0xFFEBEBEB);
const _ink = Color(0xFF222222);
const _supporting = Color(0xFF484848);
const _secondary = Color(0xFF767676);

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    required this.profile,
    this.cardApiService,
  });

  final VPayUserProfile profile;
  final CardApiService? cardApiService;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late final CardApiService _cardApiService;
  late Future<VPayCard> _cardFuture;

  @override
  void initState() {
    super.initState();
    _cardApiService = widget.cardApiService ?? CardApiService();
    _cardFuture = _cardApiService.getCurrentUserCard();
  }

  void _retry() {
    setState(() {
      _cardFuture = _cardApiService.getCurrentUserCard();
    });
  }

  void _showComingSoon(String feature) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  String get _firstName {
    final name = widget.profile.name.trim();
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Text(
                  'Welcome back',
                  style: const TextStyle(color: _secondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_greeting, $_firstName',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<VPayCard>(
                  future: _cardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _CardLoadingState();
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _CardErrorState(
                        message: _cardErrorMessage(snapshot.error),
                        onRetry: _retry,
                      );
                    }

                    final card = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BalancePanel(balance: card.balance),
                        const SizedBox(height: 20),
                        _VirtualCard(
                          card: card,
                          cardholderName: widget.profile.name,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 16),
                _buildCardAction(),
                const SizedBox(height: 28),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Home',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRect(
              child: Image.asset(
                'assets/branding/vpay_logo.png',
                width: 140,
                height: 44,
                fit: BoxFit.cover,
                semanticLabel: 'VPay',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _showComingSoon('Top Up'),
              style: FilledButton.styleFrom(
                backgroundColor: _electric,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Top Up'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showComingSoon('Scan & Pay'),
              style: OutlinedButton.styleFrom(
                backgroundColor: _surface,
                foregroundColor: _strongBlue,
                side: const BorderSide(color: _divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan & Pay'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardAction() {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showComingSoon('Freeze Card'),
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: _strongBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Freeze Card',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Available soon',
                style: TextStyle(color: _secondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            children: [
              Icon(Icons.receipt_long_outlined, color: _secondary, size: 32),
              SizedBox(height: 10),
              Text(
                'No recent activity yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _supporting,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _cardErrorMessage(Object? error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'This account cannot access a Customer virtual card.',
        404 => 'Your VPay virtual card could not be found.',
        _ => 'Something went wrong while loading your VPay card.',
      };
    }

    if (error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException) {
      return 'Unable to load your card. Check your connection and try again.';
    }

    if (error is StateError) {
      return 'Your session has expired. Please sign in again.';
    }

    return 'Something went wrong while loading your VPay card.';
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.balance});

  final num balance;

  String _formatLkr() {
    final amount = balance.abs().toStringAsFixed(2).split('.');
    final whole = amount.first;
    final grouped = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
      grouped.write(whole[index]);
    }
    final sign = balance < 0 ? '-' : '';
    return 'Rs. $sign$grouped.${amount.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(color: _secondary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatLkr(),
              style: const TextStyle(
                color: _ink,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'LKR Primary Account',
            style: TextStyle(color: _secondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _VirtualCard extends StatelessWidget {
  const _VirtualCard({required this.card, required this.cardholderName});

  final VPayCard card;
  final String cardholderName;

  String get _expiry {
    final date = card.expiresAt;
    if (date == null) return '—';
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_deepSpace, _strongBlue, _void],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1900193C),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'VPay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _CardStatusPill(status: card.status),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                card.maskedNumber ?? 'Number unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _CardDetail(
                    label: 'CARDHOLDER',
                    value: cardholderName.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 16),
                _CardDetail(label: 'EXPIRES', value: _expiry),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAFC0D4),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CardStatusPill extends StatelessWidget {
  const _CardStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'ACTIVE';
    final frozen = status == 'FROZEN';
    final color = active
        ? const Color(0xFF10B981)
        : frozen
        ? const Color(0xFFF59E0B)
        : const Color(0xFFAFC0D4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF173754),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardLoadingState extends StatelessWidget {
  const _CardLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _electric),
          SizedBox(height: 16),
          Text('Loading your VPay card…', style: TextStyle(color: _supporting)),
        ],
      ),
    );
  }
}

class _CardErrorState extends StatelessWidget {
  const _CardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.credit_card_off_outlined,
            color: _strongBlue,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'Card unavailable',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _supporting, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: _electric,
              minimumSize: const Size(120, 48),
              side: const BorderSide(color: _electric),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
