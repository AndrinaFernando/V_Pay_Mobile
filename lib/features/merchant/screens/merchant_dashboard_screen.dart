import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_service.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../auth/models/user_profile_result.dart';
import '../../auth/services/user_api_service.dart';
import '../services/payment_intent_service.dart';
import 'create_payment_request_screen.dart';
import 'merchant_profile_screen.dart';

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
    this.authService,
    this.onCreatePaymentRequest,
    this.loadProfile,
    this.paymentIntentService,
    this.userApiService,
  });

  final VPayUserProfile profile;
  final AuthService? authService;
  final VoidCallback? onCreatePaymentRequest;
  final Future<UserProfileResult> Function()? loadProfile;
  final PaymentIntentService? paymentIntentService;
  final UserApiService? userApiService;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _selectedNavigationIndex = 0;
  late VPayUserProfile _profile = widget.profile;
  bool _isRefreshingProfile = false;
  String? _profileRefreshError;

  String get _headerBusinessName {
    final businessName = _profile.businessName?.trim();
    return businessName == null || businessName.isEmpty
        ? 'Business name not provided'
        : businessName;
  }

  String get _businessCategory {
    final category = _profile.businessCategory?.trim();
    return category == null || category.isEmpty
        ? 'Business category not provided'
        : category;
  }

  String get _firstName {
    final name = _profile.name.trim();
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _showCreateRequest() async {
    if (widget.onCreatePaymentRequest != null) {
      widget.onCreatePaymentRequest!();
      if (mounted) setState(() => _selectedNavigationIndex = 0);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatePaymentRequestScreen(
          paymentIntentService: widget.paymentIntentService,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedNavigationIndex = 0);
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshingProfile) return;
    setState(() {
      _isRefreshingProfile = true;
      _profileRefreshError = null;
    });
    try {
      final result =
          await (widget.loadProfile ??
              () => UserApiService().getCurrentUserProfile())();
      if (!mounted) return;
      if (result.status == UserProfileStatus.exists && result.user != null) {
        setState(() => _profile = result.user!);
      } else {
        setState(
          () => _profileRefreshError = 'Could not refresh merchant profile.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _profileRefreshError = 'Unable to refresh your profile. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  void _onNavigationSelected(int index) {
    if (index == 1) {
      setState(() => _selectedNavigationIndex = index);
      _showCreateRequest();
      return;
    }
    if (index == 3) {
      setState(() => _selectedNavigationIndex = index);
      return;
    }
    if (index == 0) {
      setState(() => _selectedNavigationIndex = 0);
      return;
    }
    setState(() => _selectedNavigationIndex = 0);
    _showComingSoon('Payment history');
  }

  void _showComingSoon(String feature) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  Future<void> _openProfile() async {
    final authService = widget.authService;
    if (authService == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MerchantProfileScreen(
          profile: _profile,
          authService: authService,
          loadProfile: widget.loadProfile,
          userApiService: widget.userApiService,
          onProfileUpdated: (profile) => setState(() => _profile = profile),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: _canvas),
      child: Scaffold(
        backgroundColor: _canvas,
        body: SafeArea(
          bottom: false,
          child: _selectedNavigationIndex == 3
              ? _buildProfileTab()
              : _buildDashboardTab(),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrandBar(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _MerchantBalanceCard(),
                      const SizedBox(height: 16),
                      _buildCreateRequestButton(),
                      const SizedBox(height: 28),
                      _buildRecentPayments(),
                      if (_profileRefreshError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _profileRefreshError!,
                          key: const Key('merchantProfileRefreshError'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _supporting,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final authService = widget.authService;
    if (authService == null) {
      return const Center(child: Text('Merchant profile is unavailable.'));
    }

    return MerchantProfileScreen(
      profile: _profile,
      authService: authService,
      loadProfile: widget.loadProfile,
      userApiService: widget.userApiService,
      onProfileUpdated: (profile) => setState(() => _profile = profile),
      onBack: () => setState(() => _selectedNavigationIndex = 0),
    );
  }

  Widget _buildBrandBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: const BoxDecoration(color: _navy),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/branding/logos/Long Logo Dark Mode.png',
                    key: const Key('merchantDashboardLogo'),
                    width: 112,
                    height: 75,
                    fit: BoxFit.contain,
                    semanticLabel: 'VPay',
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF073A61),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'BUSINESS',
                      style: TextStyle(
                        color: Color(0xFF58C7FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('merchantProfileAction'),
                    tooltip: 'Profile',
                    onPressed: _openProfile,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF102F50),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFF4BC5FF),
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '$_headerBusinessName  •  $_businessCategory',
                        key: const Key('merchantDashboardBusinessDetails'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE1EFFB),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Your business at a glance',
                style: TextStyle(
                  color: Color(0xFFB8CEE8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$_greeting, $_firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ),
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
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
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
