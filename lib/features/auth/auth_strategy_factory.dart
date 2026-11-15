import 'auth_strategy.dart';
import 'email_password_auth_strategy.dart';

class AuthStrategyFactory {
  const AuthStrategyFactory._();

  static AuthStrategy emailPassword({
    required String email,
    required String password,
  }) {
    return EmailPasswordAuthStrategy(email: email, password: password);
  }
}
