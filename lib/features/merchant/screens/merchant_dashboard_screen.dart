import 'package:flutter/material.dart';

import '../../auth/models/vpay_user_profile.dart';
import 'create_payment_request_screen.dart';

const _canvas = Color(0xFFFCF9F8);
const _surface = Colors.white;
const _ink = Color(0xFF1B1C1C);
const _supporting = Color(0xFF5A606D);
const _divider = Color(0xFFDBE0EC);
const _electric = Color(0xFF0072DC);
const _navy = Color(0xFF00193C);
const _deepNavy = Color(0xFF012552);

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({
    super.key,
    required this.profile,
    this.onCreatePaymentRequest,
  });

  final VPayUserProfile profile;
  final VoidCallback? onCreatePaymentRequest;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _selectedNavigationIndex = 0;

  String get _businessName {
    final businessName = widget.profile.businessName?.trim();
    return businessName == null || businessName.isEmpty
        ? widget.profile.name
        : businessName;
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

  void _showCreateRequest() {
    if (widget.onCreatePaymentRequest != null) {
      widget.onCreatePaymentRequest!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreatePaymentRequestScreen(),
      ),
    );
  }

  void _onNavigationSelected(int index) {
    setState(() => _selectedNavigationIndex = index);
    if (index == 0) return;
    if (index == 1) {
      _showCreateRequest();
      return;
    }
    _showComingSoon(index == 2 ? 'Payment history' : 'Terminal tools');
    setState(() => _selectedNavigationIndex = 0);
  }

  void _showComingSoon(String feature) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrandBar(),
                    const SizedBox(height: 24),
                    _buildGreeting(),
                    const SizedBox(height: 20),
                    const _MerchantBalanceCard(),
                    const SizedBox(height: 16),
                    _buildCreateRequestButton(),
                    const SizedBox(height: 28),
                    _buildRecentPayments(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBrandBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _electric.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: _electric,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VPay Merchant',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _supporting,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _showComingSoon('Notifications'),
          style: IconButton.styleFrom(
            backgroundColor: _surface,
            foregroundColor: _supporting,
            side: const BorderSide(color: _divider),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your business at a glance',
          style: TextStyle(color: _supporting, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '$_greeting, $_firstName',
          style: const TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateRequestButton() {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: _showCreateRequest,
        style: FilledButton.styleFrom(
          backgroundColor: _electric,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.qr_code_2_rounded),
        label: const Text('Create Payment Request'),
      ),
    );
  }

  Widget _buildRecentPayments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Payments',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showComingSoon('Payment history'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _divider),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Icon(Icons.receipt_long_outlined, color: _supporting, size: 30),
              SizedBox(height: 10),
              Text(
                'No received payments to show yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Payment history will appear here when it is available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _supporting, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavigationIndex,
          onTap: _onNavigationSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _surface,
          elevation: 0,
          selectedItemColor: _electric,
          unselectedItemColor: _supporting,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_outlined),
              activeIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_2_rounded),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Payments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.devices_outlined),
              label: 'Terminal',
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantBalanceCard extends StatelessWidget {
  const _MerchantBalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _deepNavy, Color(0xFF000D20)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1600193C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -44,
            top: -52,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: _electric.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AVAILABLE BALANCE',
                      style: TextStyle(
                        color: Color(0xFFB8CEE8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white.withValues(alpha: 0.78),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Balance details aren’t available yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your merchant balance will appear here when the backend provides it.',
                style: TextStyle(
                  color: Color(0xFFB8CEE8),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
