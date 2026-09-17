import 'package:flutter/material.dart';

import '../auth_service.dart';

class AuthenticatedPlaceholderScreen extends StatelessWidget {
  const AuthenticatedPlaceholderScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Authentication successful'),
              const SizedBox(height: 8),
              const Text('VPay authenticated area'),
              const SizedBox(height: 24),
              ElevatedButton(
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
