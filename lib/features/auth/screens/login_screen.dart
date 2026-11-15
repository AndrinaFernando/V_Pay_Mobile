import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../auth_strategy_factory.dart';
import '../widgets/auth_form_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthService _authService;
  bool _isSubmitting = false;
  bool _showPassword = false;
  String? _signInError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    return value == null || value.isEmpty ? 'Password is required.' : null;
  }

  Future<void> _signIn() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    _emailController.value = _emailController.value.copyWith(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
    setState(() {
      _isSubmitting = true;
      _signInError = null;
    });

    try {
      final strategy = AuthStrategyFactory.emailPassword(
        email: email,
        password: _passwordController.text,
      );
      await _authService.signIn(strategy);
      // AuthGate observes the Firebase session and chooses the next screen.
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _signInError = _authErrorMessage(error.code));
    } catch (_) {
      if (mounted) {
        setState(() => _signInError = 'Something went wrong while signing in.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _authErrorMessage(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many sign-in attempts. Please try again later.',
    'network-request-failed' =>
      'Unable to connect. Check your internet connection and try again.',
    _ => 'Something went wrong while signing in.',
  };

  void _openRegistration() {
    if (_isSubmitting) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RegisterScreen(authService: _authService),
      ),
    );
  }

  void _openForgotPassword() {
    if (_isSubmitting) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ForgotPasswordScreen(
          authService: _authService,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to access your VPay account.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: authInputDecoration('Email'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_isSubmitting,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _signIn(),
                decoration: authInputDecoration(
                  'Password',
                  suffixIcon: IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: vPayMuted,
                    ),
                  ),
                ),
                validator: _validatePassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _openForgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: vPayBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_signInError != null) ...[
                const SizedBox(height: 4),
                AuthErrorMessage(_signInError!),
              ],
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: 'Sign In',
                isLoading: _isSubmitting,
                onPressed: _signIn,
              ),
              const SizedBox(height: 8),
              AuthInlineAction(
                prompt: "Don't have an account?",
                actionLabel: 'Create account',
                onPressed: _isSubmitting ? null : _openRegistration,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
