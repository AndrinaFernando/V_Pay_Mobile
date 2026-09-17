import 'package:firebase_auth/firebase_auth.dart';

import 'auth_strategy.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

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

  Future<void> signOut() {
    return _auth.signOut();
  }
}
