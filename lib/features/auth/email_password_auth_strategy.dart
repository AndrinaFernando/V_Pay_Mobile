import 'package:firebase_auth/firebase_auth.dart';

import 'auth_strategy.dart';

class EmailPasswordAuthStrategy implements AuthStrategy {
  EmailPasswordAuthStrategy({required this.email, required this.password});

  final String email;
  final String password;

  @override
  Future<UserCredential> signIn(FirebaseAuth auth) {
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }
}
