import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/security/local_auth_service.dart';
import 'auth_service.dart';

class AppAccessGate extends StatefulWidget {
  const AppAccessGate({
    super.key,
    required this.authService,
    required this.child,
    this.localAuthService,
  });

  static const backgroundGracePeriod = Duration(seconds: 60);

  final AuthService authService;
  final Widget child;
  final LocalAuthService? localAuthService;

  @override
  State<AppAccessGate> createState() => _AppAccessGateState();
}

class _AppAccessGateState extends State<AppAccessGate>
    with WidgetsBindingObserver {
  late final LocalAuthService _localAuthService;
  Timer? _backgroundLockTimer;
  DateTime? _backgroundedAt;
  bool? _isDeviceAuthAvailable;
  bool _isUnlocked = false;
  bool _isCheckingAvailability = false;
  bool _isAuthenticating = false;
  bool _lockedByBackgroundTimeout = false;
  bool _isSigningOut = false;
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    _localAuthService = widget.localAuthService ?? LocalAuthService();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkAvailabilityAndAuthenticate());
    });
  }

  @override
  void dispose() {
    _backgroundLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAuthenticating) return;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _handleBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _handleResumed();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _handleBackgrounded() {
    if (!_isUnlocked || _backgroundedAt != null) return;

    _backgroundedAt = DateTime.now();
    _backgroundLockTimer = Timer(AppAccessGate.backgroundGracePeriod, () {
      if (!mounted || _backgroundedAt == null || _isAuthenticating) return;

      setState(() {
        _isUnlocked = false;
        _lockedByBackgroundTimeout = true;
      });
    });
  }

  void _handleResumed() {
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return;

    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = null;
    _backgroundedAt = null;

    final gracePeriodExpired =
        _lockedByBackgroundTimeout ||
        DateTime.now().difference(backgroundedAt) >=
            AppAccessGate.backgroundGracePeriod;
    _lockedByBackgroundTimeout = false;

    if (!gracePeriodExpired) return;

    if (_isUnlocked) setState(() => _isUnlocked = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkAvailabilityAndAuthenticate());
    });
  }

  Future<void> _checkAvailabilityAndAuthenticate() async {
    if (_isCheckingAvailability || _isAuthenticating || _isUnlocked) return;

    setState(() {
      _isCheckingAvailability = true;
      _signOutError = null;
    });

    final isAvailable = await _localAuthService.isAvailable();
    if (!mounted) return;

    setState(() {
      _isDeviceAuthAvailable = isAvailable;
      _isCheckingAvailability = false;
    });

    if (isAvailable) await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || _isUnlocked) return;

    setState(() => _isAuthenticating = true);
    var authenticated = false;
    try {
      authenticated = await _localAuthService.authenticateForAppAccess();
    } catch (_) {
      // Remain locked and allow a manual retry.
    }
    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
      if (authenticated) _isUnlocked = true;
    });
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });

    try {
      await widget.authService.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _signOutError = 'Unable to sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) return widget.child;

    final unavailable =
        _isDeviceAuthAvailable == false && !_isCheckingAvailability;
    final busy = _isCheckingAvailability || _isAuthenticating || _isSigningOut;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/vpay_logo.png',
                    width: 144,
                    semanticLabel: 'VPay',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    unavailable
                        ? 'Device screen-lock authentication is required to access VPay.'
                        : 'Unlock VPay to access your account and payment information.',
                    style: const TextStyle(
                      color: Color(0xFF484848),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: busy
                          ? null
                          : () =>
                                unawaited(_checkAvailabilityAndAuthenticate()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072DC),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF0072DC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              unavailable ? 'Check Again' : 'Unlock VPay',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    unavailable
                        ? 'Set up a device PIN, passcode, pattern, fingerprint, or face authentication, then check again.'
                        : 'VPay uses your device screen lock. Your fingerprint, face data, and passcode stay on your device.',
                    style: const TextStyle(
                      color: Color(0xFF767676),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (_signOutError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _signOutError!,
                      style: const TextStyle(
                        color: Color(0xFFB3261E),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : _signOut,
                    child: Text(_isSigningOut ? 'Signing out…' : 'Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
