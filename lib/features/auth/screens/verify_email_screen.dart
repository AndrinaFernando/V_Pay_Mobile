import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.authService,
    required this.onEmailVerified,
  });

  final AuthService authService;
  final VoidCallback onEmailVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _resendTimer;
  int _secondsUntilResend = 60;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _secondsUntilResend = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() {
          _secondsUntilResend = 0;
        });
        return;
      }

      setState(() {
        _secondsUntilResend--;
      });
    });
  }

  Future<void> _checkVerification() async {
    try {
      final user = await widget.authService.reloadCurrentUser();

      if (!mounted) {
        return;
      }

      if (user?.emailVerified ?? false) {
        widget.onEmailVerified();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your email is not verified yet.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh verification status.')),
      );
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _secondsUntilResend > 0) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await widget.authService.resendVerificationEmail();

      if (!mounted) {
        return;
      }

      _startResendCooldown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'too-many-requests'
          ? 'Too many verification emails were requested. Please wait and try again.'
          : 'Unable to resend the verification email.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resend the verification email.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authService.currentUser?.email;
    final canResend = _secondsUntilResend == 0 && !_isResending;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('A verification email has been sent to:'),
              const SizedBox(height: 8),
              Text(email ?? 'your email address'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkVerification,
                child: const Text("I've Verified My Email"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canResend ? _resendVerificationEmail : null,
                child: Text(
                  _isResending ? 'Resending...' : 'Resend Verification Email',
                ),
              ),
              if (_secondsUntilResend > 0) ...[
                const SizedBox(height: 8),
                Text('Resend available in ${_secondsUntilResend}s'),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.authService.signOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
