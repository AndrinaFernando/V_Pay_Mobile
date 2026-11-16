import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

import '../../core/notifications/firebase_notifications.dart';
import '../../core/notifications/notification_open_coordinator.dart';
import '../card/services/card_api_service.dart';
import '../customer/services/customer_transaction_service.dart';
import '../merchant/services/merchant_balance_service.dart';
import '../merchant/services/merchant_received_payments_service.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/user_api_service.dart';
import 'vpay_account_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.userApiService,
    this.cardApiService,
    this.customerTransactionService,
    this.merchantBalanceService,
    this.merchantReceivedPaymentsService,
  });

  final AuthService? authService;
  final UserApiService? userApiService;
  final CardApiService? cardApiService;
  final CustomerTransactionService? customerTransactionService;
  final MerchantBalanceService? merchantBalanceService;
  final MerchantReceivedPaymentsService? merchantReceivedPaymentsService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  NotificationOpenCoordinator? _notificationOpens;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _notificationOpens = firebaseNotificationOpens(_authService);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _notificationOpens?.dispose();
    super.dispose();
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
          return LoginScreen(authService: _authService);
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
          userApiService: widget.userApiService,
          notificationOpens: _notificationOpens,
          cardApiService: widget.cardApiService,
          customerTransactionService: widget.customerTransactionService,
          merchantBalanceService: widget.merchantBalanceService,
          merchantReceivedPaymentsService:
              widget.merchantReceivedPaymentsService,
        );
      },
    );
  }
}
