import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthStrategy {
  Future<UserCredential> signIn(FirebaseAuth auth);
}
