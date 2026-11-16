import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/models/user_profile_result.dart';
import '../auth/models/vpay_user_profile.dart';
import '../auth/services/user_api_service.dart';
import 'about_vpay_screen.dart';
import 'account_details_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'logout_confirmation_dialog.dart';
import 'privacy_policy_screen.dart';
import 'terms_and_conditions_screen.dart';
import 'vpay_colors.dart';

/// Unified profile screen shared by both Customer and Merchant accounts.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.authService,
    this.loadProfile,
    this.onBack,
    this.userApiService,
    this.onProfileUpdated,
  });

  final VPayUserProfile profile;
  final AuthService authService;
  final Future<UserProfileResult> Function()? loadProfile;
  final VoidCallback? onBack;
  final UserApiService? userApiService;
  final ValueChanged<VPayUserProfile>? onProfileUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late VPayUserProfile? _profile = widget.profile;
  bool _isLoading = false;
  bool _logoutDialogOpen = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.loadProfile != null) _refreshProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _profile = widget.profile;
  }

  Future<void> _refreshProfile() async {
    final loadProfile = widget.loadProfile;
    if (loadProfile == null || _isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final result = await loadProfile();
      if (!mounted) return;
      setState(() {
        _profile = result.status == UserProfileStatus.exists
            ? result.user
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'We could not load your profile. Check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _initials {
    final name = _profile!.name.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first.characters.first}${parts.last.characters.first}'
          .toUpperCase();
    }
    return parts.first.characters.first.toUpperCase();
  }

  bool get _isMerchant => _profile!.role.trim().toUpperCase() == 'MERCHANT';

  Future<void> _handleLogout() async {
    if (_logoutDialogOpen) return;
    setState(() => _logoutDialogOpen = true);
    final navigator = Navigator.of(context);
    try {
      final confirmed = await showLogoutConfirmationDialog(
        context,
        authService: widget.authService,
      );
      if (confirmed && navigator.mounted) {
        // Reveal AuthGate after closing any profile route opened from the header.
        navigator.popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _logoutDialogOpen = false);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<VPayUserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: _profile!,
          userApiService: widget.userApiService,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
    widget.onProfileUpdated?.call(updated);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VPayColors.canvas,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        backgroundColor: VPayColors.canvas,
        foregroundColor: VPayColors.ink,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.loadProfile != null)
            IconButton(
              tooltip: 'Refresh profile',
              onPressed: _isLoading ? null : _refreshProfile,
              icon: const Icon(Icons.refresh_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Image.asset(
              'assets/branding/logos/Logo Blue V2.0.png',
              width: 32,
              height: 32,
              semanticLabel: 'VPay',
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('profileLoading'),
          color: VPayColors.electric,
        ),
      );
    }
    if (_loadError != null || _profile == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: VPayColors.secondary,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError ?? 'Profile details are unavailable.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _refreshProfile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: VPayColors.electric,
                  side: const BorderSide(color: VPayColors.divider),
                  minimumSize: const Size(96, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: _logoutDialogOpen ? null : _handleLogout,
                style: TextButton.styleFrom(foregroundColor: VPayColors.error),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      );
    }
    final list = ListView(
      key: const Key('profileScrollView'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 28),
        _buildSectionHeader('ACCOUNT'),
        const SizedBox(height: 10),
        _buildMenuCard([
          _MenuItem(
            key: const Key('profileAccountDetails'),
            icon: Icons.person_outline_rounded,
            title: 'Account Details',
            onTap: () => _navigateTo(AccountDetailsScreen(profile: _profile!)),
          ),
          _MenuItem(
            key: const Key('profileEditProfile'),
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: _editProfile,
          ),
          _MenuItem(
            key: const Key('profileLogout'),
            icon: Icons.logout_rounded,
            title: 'Log Out',
            iconColor: VPayColors.error,
            titleColor: VPayColors.error,
            showChevron: false,
            onTap: _logoutDialogOpen ? null : _handleLogout,
            isLast: true,
          ),
        ]),
        const SizedBox(height: 24),
        _buildSectionHeader('SUPPORT'),
        const SizedBox(height: 10),
        _buildMenuCard([
          _MenuItem(
            key: const Key('profileHelpCenter'),
            icon: Icons.help_outline_rounded,
            title: 'Help Center',
            onTap: () => _navigateTo(const HelpCenterScreen()),
            isLast: true,
          ),
        ]),
        const SizedBox(height: 24),
        _buildSectionHeader('ABOUT'),
        const SizedBox(height: 10),
        _buildMenuCard([
          _MenuItem(
            key: const Key('profileAboutVPay'),
            icon: Icons.info_outline_rounded,
            title: 'About VPay',
            onTap: () => _navigateTo(const AboutVPayScreen()),
          ),
          _MenuItem(
            key: const Key('profileTerms'),
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => _navigateTo(const TermsAndConditionsScreen()),
          ),
          _MenuItem(
            key: const Key('profilePrivacy'),
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _navigateTo(const PrivacyPolicyScreen()),
            isLast: true,
          ),
        ]),
      ],
    );
    if (widget.loadProfile == null) return list;
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      color: VPayColors.electric,
      child: list,
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar with initials
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: VPayColors.electric.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(
              color: VPayColors.electric.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _initials,
                style: const TextStyle(
                  color: VPayColors.electric,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Full name
        Text(
          _profile!.name.trim().isEmpty
              ? 'Not provided'
              : _profile!.name.trim(),
          key: const Key('profileName'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: VPayColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        // Email
        Text(
          _profile!.email.trim().isEmpty
              ? 'Not provided'
              : _profile!.email.trim(),
          key: const Key('profileEmail'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: VPayColors.secondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        // Role chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: VPayColors.electric.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _profile!.role.toUpperCase(),
            key: const Key('profileRole'),
            style: const TextStyle(
              color: VPayColors.electric,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Business name for merchants
        if (_isMerchant &&
            _profile!.businessName != null &&
            _profile!.businessName!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _profile!.businessName!.trim(),
            key: const Key('profileBusinessName'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VPayColors.secondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: VPayColors.secondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: VPayColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VPayColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = VPayColors.ink,
    this.titleColor = VPayColors.ink,
    this.showChevron = true,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color titleColor;
  final bool showChevron;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: VPayColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showChevron)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: VPayColors.secondary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: VPayColors.divider,
            indent: 52,
          ),
      ],
    );
  }
}
