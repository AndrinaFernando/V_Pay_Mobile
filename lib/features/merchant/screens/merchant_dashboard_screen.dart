import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/navigation/vpay_tab_transition.dart';
import '../../auth/auth_service.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../auth/models/user_profile_result.dart';
import '../../auth/services/user_api_service.dart';
import '../models/merchant_balance.dart';
import '../models/merchant_received_payment.dart';
import '../services/merchant_balance_service.dart';
import '../services/merchant_received_payments_service.dart';
import '../services/payment_intent_service.dart';
import 'create_payment_request_screen.dart';
import 'merchant_profile_screen.dart';
import '../widgets/merchant_received_payment_tile.dart';

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
    this.merchantBalanceService,
    this.merchantReceivedPaymentsService,
  });

  final VPayUserProfile profile;
  final AuthService? authService;
  final VoidCallback? onCreatePaymentRequest;
  final Future<UserProfileResult> Function()? loadProfile;
  final PaymentIntentService? paymentIntentService;
  final UserApiService? userApiService;
  final MerchantBalanceService? merchantBalanceService;
  final MerchantReceivedPaymentsService? merchantReceivedPaymentsService;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedNavigationIndex = 0;
  bool _profileVisited = false;
  late final AnimationController _tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late VPayUserProfile _profile = widget.profile;
  bool _isRefreshingProfile = false;
  String? _profileRefreshError;
  late final MerchantBalanceService _merchantBalanceService;
  MerchantBalance? _merchantBalance;
  Future<void>? _balanceLoad;
  bool _isLoadingBalance = true;
  String? _balanceError;
  int _merchantDataRefreshRevision = 0;
  late final MerchantReceivedPaymentsService _merchantReceivedPaymentsService;
  List<MerchantReceivedPayment> _receivedPayments = const [];
  Future<void>? _receivedPaymentsLoad;
  bool _isLoadingReceivedPayments = true;
  String? _receivedPaymentsError;

  @override
  void initState() {
    super.initState();
    _merchantBalanceService =
        widget.merchantBalanceService ?? ApiMerchantBalanceService();
    _merchantReceivedPaymentsService =
        widget.merchantReceivedPaymentsService ??
        ApiMerchantReceivedPaymentsService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadBalance());
    unawaited(_loadReceivedPayments());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabAnimation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_selectedNavigationIndex == 0 || _selectedNavigationIndex == 2)) {
      unawaited(_loadBalance());
      unawaited(_loadReceivedPayments());
    }
  }

  void _selectVisibleTab(int index) {
    if (index == _selectedNavigationIndex) return;
    setState(() {
      _selectedNavigationIndex = index;
      if (index == 3) _profileVisited = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) return;
    _tabAnimation.forward(from: 0);
  }

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
    final refreshRevisionBeforePush = _merchantDataRefreshRevision;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatePaymentRequestScreen(
          paymentIntentService: widget.paymentIntentService,
          onConfirmedPaymentSuccess: _refreshMerchantData,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedNavigationIndex = 0);
    if (_merchantDataRefreshRevision == refreshRevisionBeforePush) {
      unawaited(_refreshMerchantData());
    }
  }

  Future<void> _loadBalance() {
    final inProgress = _balanceLoad;
    if (inProgress != null) return inProgress;

    final load = _fetchBalance();
    _balanceLoad = load;
    return load.whenComplete(() {
      if (identical(_balanceLoad, load)) _balanceLoad = null;
    });
  }

  Future<void> _fetchBalance() async {
    if (mounted) {
      setState(() {
        _isLoadingBalance = true;
        _balanceError = null;
      });
    }

    try {
      final balance = await _merchantBalanceService.getMerchantBalance();
      if (!mounted) return;
      setState(() {
        _merchantBalance = balance;
        _balanceError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _merchantBalance = null;
        _balanceError = _balanceErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  String _balanceErrorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Your session has expired. Sign in again to view your balance.',
        403 => 'This account is not authorized to view a merchant balance.',
        404 => 'Your merchant wallet is not available yet.',
        409 => 'Your merchant wallet is currently unavailable.',
        _ => 'We could not load your merchant balance. Please try again.',
      };
    }
    return 'Check your connection and retry to load your merchant balance.';
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      _refreshProfile(),
      _loadBalance(),
      _loadReceivedPayments(),
    ]);
  }

  Future<void> _refreshMerchantData() async {
    _merchantDataRefreshRevision++;
    await Future.wait([_loadBalance(), _loadReceivedPayments()]);
  }

  Future<void> _loadReceivedPayments() {
    final inProgress = _receivedPaymentsLoad;
    if (inProgress != null) return inProgress;

    final load = _fetchReceivedPayments();
    _receivedPaymentsLoad = load;
    return load.whenComplete(() {
      if (identical(_receivedPaymentsLoad, load)) {
        _receivedPaymentsLoad = null;
      }
    });
  }

  Future<void> _fetchReceivedPayments() async {
    if (mounted) {
      setState(() {
        _isLoadingReceivedPayments = true;
        _receivedPaymentsError = null;
      });
    }

    try {
      final payments = await _merchantReceivedPaymentsService
          .getReceivedPayments(limit: 50);
      if (!mounted) return;
      setState(() {
        _receivedPayments = payments;
        _receivedPaymentsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _receivedPayments = const [];
        _receivedPaymentsError = _receivedPaymentsErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isLoadingReceivedPayments = false);
    }
  }

  String _receivedPaymentsErrorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'This account cannot access merchant payment history.',
        400 => 'The payment history request is invalid.',
        _ => 'We could not load received payments. Please try again.',
      };
    }
    return 'Check your connection and retry to load received payments.';
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
      _selectVisibleTab(index);
      return;
    }
    if (index == 2) {
      _selectVisibleTab(index);
      unawaited(_loadReceivedPayments());
      return;
    }
    if (index == 0) {
      _selectVisibleTab(0);
      unawaited(_refreshMerchantData());
      return;
    }
    setState(() => _selectedNavigationIndex = 0);
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
    if (mounted) await _refreshMerchantData();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: _canvas),
      child: Scaffold(
        backgroundColor: _canvas,
        body: SafeArea(
          bottom: false,
          child: VPayTabTransition(
            animation: _tabAnimation,
            child: IndexedStack(
              index: switch (_selectedNavigationIndex) {
                2 => 1,
                3 => 2,
                _ => 0,
              },
              children: [
                _buildDashboardTab(),
                _buildPaymentsTab(),
                _profileVisited ? _buildProfileTab() : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
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
                      _MerchantBalanceCard(
                        balance: _merchantBalance,
                        isLoading: _isLoadingBalance,
                        errorMessage: _balanceError,
                        onRetry: () => unawaited(_loadBalance()),
                      ),
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
      onBack: () {
        _selectVisibleTab(0);
        unawaited(_refreshMerchantData());
      },
    );
  }

  Widget _buildPaymentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBrandBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Received Payments',
                  key: Key('merchantReceivedPaymentsTitle'),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_receivedPayments.length} latest',
                style: const TextStyle(color: _supporting, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            key: const Key('merchantReceivedPaymentsRefresh'),
            onRefresh: _loadReceivedPayments,
            color: _electric,
            child: _buildReceivedPaymentsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReceivedPaymentsList() {
    if (_isLoadingReceivedPayments) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: const [_ReceivedPaymentsSkeleton(fullPage: true)],
      );
    }
    if (_receivedPaymentsError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _ReceivedPaymentsMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load received payments',
            message: _receivedPaymentsError!,
            actionLabel: 'Retry',
            onAction: () => unawaited(_loadReceivedPayments()),
          ),
        ],
      );
    }
    if (_receivedPayments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _ReceivedPaymentsMessage(
            icon: Icons.receipt_long_outlined,
            title: 'No received payments yet',
            message: 'Completed QR payments will appear here.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: _receivedPayments.length,
      itemBuilder: (context, index) => DecoratedBox(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(
            top: index == 0 ? const Radius.circular(18) : Radius.zero,
            bottom: index == _receivedPayments.length - 1
                ? const Radius.circular(18)
                : Radius.zero,
          ),
        ),
        child: MerchantReceivedPaymentTile(payment: _receivedPayments[index]),
      ),
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
              key: const Key('viewAllMerchantPayments'),
              onPressed: () => _onNavigationSelected(2),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_isLoadingReceivedPayments)
          const _ReceivedPaymentsSkeleton()
        else if (_receivedPaymentsError != null)
          _ReceivedPaymentsMessage(
            key: const Key('merchantRecentPaymentsError'),
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load received payments',
            message: _receivedPaymentsError!,
            actionLabel: 'Retry',
            onAction: () => unawaited(_loadReceivedPayments()),
          )
        else if (_receivedPayments.isEmpty)
          const _ReceivedPaymentsMessage(
            key: Key('merchantRecentPaymentsEmpty'),
            icon: Icons.receipt_long_outlined,
            title: 'No received payments to show yet',
            message: 'Completed QR payments will appear here.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _divider),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final payment in _receivedPayments.take(3))
                  MerchantReceivedPaymentTile(payment: payment, compact: true),
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

class _ReceivedPaymentsSkeleton extends StatelessWidget {
  const _ReceivedPaymentsSkeleton({this.fullPage = false});

  final bool fullPage;

  @override
  Widget build(BuildContext context) {
    final item = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE7ECF3),
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 135,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7ECF3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 185,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7ECF3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Loading received payments',
      child: fullPage
          ? Column(
              children: [
                for (var index = 0; index < 5; index++) ...[
                  item,
                  if (index < 4) const SizedBox(height: 8),
                ],
              ],
            )
          : Container(
              key: const Key('merchantRecentPaymentsSkeleton'),
              child: Column(children: [item, const SizedBox(height: 8), item]),
            ),
    );
  }
}

class _ReceivedPaymentsMessage extends StatelessWidget {
  const _ReceivedPaymentsMessage({
    super.key,
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
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _supporting, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _supporting,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('retryMerchantReceivedPayments'),
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MerchantBalanceCard extends StatelessWidget {
  const _MerchantBalanceCard({
    required this.balance,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final MerchantBalance? balance;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

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
              if (balance != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance!.formattedLkr,
                    key: const Key('merchantBalanceValue'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                )
              else if (isLoading)
                _buildSkeleton()
              else
                _buildError(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Semantics(
      label: 'Loading merchant balance',
      child: Column(
        key: const Key('merchantBalanceSkeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 190,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 220,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Column(
      key: const Key('merchantBalanceError'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          errorMessage ?? 'We could not load your merchant balance.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('merchantBalanceRetry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8FD8FF),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
