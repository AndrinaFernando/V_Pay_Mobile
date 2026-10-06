import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'app_access_gate.dart';
import 'auth_service.dart';
import 'models/user_profile_result.dart';
import 'screens/authenticated_placeholder_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'services/user_api_service.dart';

class VPayAccountGate extends StatefulWidget {
  const VPayAccountGate({
    super.key,
    required this.authService,
    this.userApiService,
  });

  final AuthService authService;
  final UserApiService? userApiService;

  @override
  State<VPayAccountGate> createState() => _VPayAccountGateState();
}

class _VPayAccountGateState extends State<VPayAccountGate> {
  late final UserApiService _userApiService;
  late Future<UserProfileResult> _profileCheck;

  @override
  void initState() {
    super.initState();
    _userApiService = widget.userApiService ?? UserApiService();
    _profileCheck = _userApiService.getCurrentUserProfile();
  }

  void _retry() {
    setState(() {
      _profileCheck = _userApiService.getCurrentUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileResult>(
      future: _profileCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0072DC)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ProfileCheckError(
            message: _friendlyErrorMessage(snapshot.error),
            onRetry: _retry,
          );
        }

        final result = snapshot.data;

        if (result?.status == UserProfileStatus.exists) {
          return AppAccessGate(
            authService: widget.authService,
            child: AuthenticatedPlaceholderScreen(
              authService: widget.authService,
            ),
          );
        }

        if (result?.status == UserProfileStatus.missing) {
          return CompleteProfileScreen(
            authService: widget.authService,
            userApiService: _userApiService,
            onProfileCompleted: _retry,
          );
        }

        return _ProfileCheckError(
          message: 'We couldn\'t check your VPay profile. Please try again.',
          onRetry: _retry,
        );
      },
    );
  }

  String _friendlyErrorMessage(Object? error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Your session needs attention. Please try again.',
        403 => 'Email verification is required. Please try again after verifying your email.',
        _ => 'We couldn\'t check your VPay profile. Check your connection and try again.',
      };
    }

    return 'We couldn\'t check your VPay profile. Check your connection and try again.';
  }
}

class _ProfileCheckError extends StatelessWidget {
  const _ProfileCheckError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: Color(0xFF01397C),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Profile check unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF767676),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072DC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
