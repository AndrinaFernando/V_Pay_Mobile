import 'package:flutter/material.dart';

import '../auth_service.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({
    super.key,
    required this.authService,
    required this.onEmailVerified,
  });

  final AuthService authService;
  final VoidCallback onEmailVerified;

  Future<void> _checkVerification(BuildContext context) async {
    try {
      final user = await authService.reloadCurrentUser();

      if (!context.mounted) {
        return;
      }

      if (user?.emailVerified ?? false) {
        onEmailVerified();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your email is not verified yet.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh verification status.')),
      );
    }
  }

  Future<void> _resendVerificationEmail(BuildContext context) async {
    try {
      await authService.resendVerificationEmail();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on StateError catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resend the verification email.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email;

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
                onPressed: () => _checkVerification(context),
                child: const Text("I've Verified My Email"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _resendVerificationEmail(context),
                child: const Text('Resend Verification Email'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: authService.signOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
