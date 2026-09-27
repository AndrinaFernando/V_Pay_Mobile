import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/verify_email_screen.dart';
import 'vpay_account_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  void _refreshUserState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = _authService.currentUser;

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return VerifyEmailScreen(
            authService: _authService,
            onEmailVerified: _refreshUserState,
          );
        }

        return VPayAccountGate(
          key: ValueKey(user.uid),
          authService: _authService,
        );
      },
    );
  }
}
