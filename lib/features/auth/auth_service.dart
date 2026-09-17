import 'package:firebase_auth/firebase_auth.dart';

import 'auth_strategy.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<UserCredential> signIn(AuthStrategy strategy) {
    return strategy.signIn(_auth);
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

  Future<void> signOut() {
    return _auth.signOut();
  }
}
