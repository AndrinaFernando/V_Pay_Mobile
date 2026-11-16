import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/network/api_client.dart';
import '../../core/notifications/notification_binding.dart';
import '../../core/notifications/notification_service.dart';

import 'auth_strategy.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    this.unregisterNotificationToken,
    this.notificationUnregisterTimeout = const Duration(seconds: 2),
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final Future<void> Function(String token, String bindingId)?
  unregisterNotificationToken;
  final Duration notificationUnregisterTimeout;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<UserCredential> signIn(AuthStrategy strategy) {
    return strategy.signIn(_auth);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase did not return a user after registration.');
    }

    await user.sendEmailVerification();
    return credential;
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No signed-in user is available to verify.');
    }

    if (user.emailVerified) {
      return;
    }

    await user.sendEmailVerification();
  }

  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    await user.reload();
    return _auth.currentUser;
  }

  Future<String?> getFreshIdToken() {
    return _auth.currentUser?.getIdToken(true) ?? Future.value(null);
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    final token = NotificationBinding.token;
    final bindingId = NotificationBinding.id;
    final ownsBinding = uid != null && NotificationBinding.uid == uid;
    NotificationBinding.clear();
    if (uid != null && ownsBinding && token != null && bindingId != null) {
      try {
        await (unregisterNotificationToken?.call(token, bindingId) ??
                NotificationTokenApi(ApiClient(authService: this))
                    .unregister(token, bindingId))
            .timeout(notificationUnregisterTimeout);
      } catch (_) {
        // Offline logout still clears the local binding. A stale generic OS
        // alert contains no account information and cannot refresh the app.
      }
    }
    await _auth.signOut();
  }
}
