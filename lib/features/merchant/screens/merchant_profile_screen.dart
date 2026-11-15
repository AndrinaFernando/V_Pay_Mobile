import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_service.dart';
import '../../auth/models/user_profile_result.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../auth/services/user_api_service.dart';

const _blue = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF767676);
const _line = Color(0xFFEBEBEB);
const _navy = Color(0xFF00193C);
const _deepNavy = Color(0xFF012552);

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({
    super.key,
    required this.profile,
    required this.authService,
    this.loadProfile,
    this.onBack,
  });

  final VPayUserProfile profile;
  final AuthService authService;
  final Future<UserProfileResult> Function()? loadProfile;
  final VoidCallback? onBack;

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  late final Future<UserProfileResult> Function() _loadProfile =
      widget.loadProfile ?? UserApiService().getCurrentUserProfile;
  late VPayUserProfile? _profile;
  bool _isLoading = true;
  bool _isSigningOut = false;
  String? _loadError;
  String? _logoutError;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final result = await _loadProfile();
      if (!mounted) return;
      setState(() {
        _profile = result.status == UserProfileStatus.exists
            ? result.user
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'We could not load your profile. Check your connection and retry.';
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use VPay.'),
        actions: [
          TextButton(
            key: const Key('merchantLogoutCancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('merchantLogoutConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSigningOut = true;
      _logoutError = null;
    });
    try {
      // AuthGate listens to Firebase authStateChanges and replaces this
      // protected account subtree with the existing login screen on success.
      await widget.authService.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _logoutError =
            'Log out failed. Please check your connection and try again.';
      });
    }
  }

  String _display(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: PopScope(
        canPop: !_isSigningOut,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              key: const Key('merchantProfileBack'),
              tooltip: 'Back to dashboard',
              onPressed: () {
                final onBack = widget.onBack;
                if (onBack != null) {
                  onBack();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            titleSpacing: 0,
            title: const Text(
              'Profile',
              key: Key('merchantProfileTitle'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Image.asset(
                    'assets/branding/logos/Logo Blue V2.0.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    semanticLabel: 'VPay',
                  ),
                ),
              ),
            ],
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: _line),
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      key: Key('merchantProfileLoading'),
                      color: _blue,
                    ),
                  )
                : _loadError != null
                ? _buildError()
                : _profile == null
                ? _buildMissingProfile()
                : _buildProfile(_profile!),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: _muted),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('merchantProfileRetry'),
            onPressed: _refreshProfile,
            child: const Text('Retry'),
          ),
          _logoutButton(),
        ],
      ),
    ),
  );

  Widget _buildMissingProfile() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_search_outlined, size: 42, color: _muted),
          const SizedBox(height: 12),
          const Text(
            'Merchant profile details are unavailable.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('merchantProfileRetry'),
            onPressed: _refreshProfile,
            child: const Text('Retry'),
          ),
          _logoutButton(),
        ],
      ),
    ),
  );

  Widget _buildProfile(VPayUserProfile profile) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      _businessCard(profile),
      const SizedBox(height: 22),
      Row(
        children: [
          const Expanded(
            child: Text(
              'ACCOUNT DETAILS',
              style: TextStyle(
                color: Color(0xFF63758D),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            profile.role,
            key: const Key('merchantProfileRole'),
            style: const TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _detail('ACCOUNT NAME', profile.name, Icons.person_outline, 0),
            _detail('EMAIL', profile.email, Icons.mail_outline_rounded, 1),
            _detail('PHONE', profile.phone, Icons.call_outlined, 2),
            _detail(
              'BUSINESS NAME',
              profile.businessName,
              Icons.store_outlined,
              3,
            ),
            _detail(
              'BUSINESS CATEGORY',
              profile.businessCategory,
              Icons.category_outlined,
              4,
            ),
            _detail(
              'BUSINESS ADDRESS',
              profile.businessAddress,
              Icons.location_on_outlined,
              5,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (_logoutError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _logoutError!,
            key: const Key('merchantLogoutError'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC74A4A)),
          ),
        ),
      _logoutButton(),
    ],
  );

  Widget _businessCard(VPayUserProfile profile) {
    final isActive = profile.status.trim().toUpperCase() == 'ACTIVE';
    return Container(
      key: const Key('merchantProfileBusinessCard'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _deepNavy],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2400193C),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF42A5FF),
              size: 36,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            _display(profile.businessName),
            key: const Key('merchantProfileBusinessName'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _profileChip(
                Icons.category_outlined,
                _display(profile.businessCategory),
              ),
              _profileChip(
                isActive ? Icons.check_circle_outline : Icons.info_outline,
                _display(profile.status),
                active: isActive,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
        ],
      ),
    );
  }

  Widget _profileChip(IconData icon, String label, {bool active = false}) {
    final color = active ? const Color(0xFF29C69A) : const Color(0xFFDCE8F5);
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF063B49)
            : Colors.white.withValues(alpha: 0.09),
        border: Border.all(
          color: active
              ? const Color(0xFF087F83)
              : Colors.white.withValues(alpha: 0.16),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String? value, IconData icon, int colorIndex) {
    const iconBackgrounds = [
      Color(0xFFEAF3FF),
      Color(0xFFEAF8FF),
      Color(0xFFF0EFFF),
      Color(0xFFE8FBFC),
      Color(0xFFFFF7E8),
      Color(0xFFFFEFF1),
    ];
    const iconColors = [
      Color(0xFF2369B3),
      Color(0xFF1E8AA8),
      Color(0xFF6557C9),
      Color(0xFF168B9B),
      Color(0xFFD58B22),
      Color(0xFFE25670),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackgrounds[colorIndex],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColors[colorIndex], size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF91A2B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _display(value),
                      key: Key('merchantProfileDetail-$label'),
                      maxLines: label == 'BUSINESS ADDRESS' ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (colorIndex < 5)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
      ],
    );
  }

  Widget _logoutButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      key: const Key('merchantLogoutButton'),
      onPressed: _isSigningOut ? null : _confirmLogout,
      icon: _isSigningOut
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(_isSigningOut ? 'Logging out…' : 'Log out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC74A4A),
        side: const BorderSide(color: Color(0xFFC74A4A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
