import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../widgets/auth_form_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AuthService _authService;
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _registrationError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _register() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    _emailController.value = _emailController.value.copyWith(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
    setState(() {
      _isSubmitting = true;
      _registrationError = null;
    });

    try {
      await _authService.registerWithEmailPassword(
        email: email,
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _registrationError = _errorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _registrationError = 'Unable to create your account.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _errorMessage(String code) => switch (code) {
    'email-already-in-use' =>
      'An account already exists for this email address.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password with at least 6 characters.',
    'network-request-failed' =>
      'Unable to connect. Check your internet connection and try again.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    _ => 'Unable to create your account. Please try again.',
  };

  void _returnToSignIn() {
    if (!_isSubmitting) Navigator.of(context).pop();
  }

  Widget _visibilityButton({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: _isSubmitting ? null : onPressed,
      tooltip: visible ? 'Hide password' : 'Show password',
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: vPayMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      title: 'Create your account',
      subtitle: 'Get started with VPay.',
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: authInputDecoration(
                  'Password',
                  suffixIcon: _visibilityButton(
                    visible: _showPassword,
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                enabled: !_isSubmitting,
                obscureText: !_showConfirmPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _register(),
                decoration: authInputDecoration(
                  'Confirm password',
                  suffixIcon: _visibilityButton(
                    visible: _showConfirmPassword,
                    onPressed: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    ),
                  ),
                ),
                validator: _validateConfirmPassword,
              ),
              if (_registrationError != null) ...[
                const SizedBox(height: 16),
                AuthErrorMessage(_registrationError!),
              ],
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Create Account',
                isLoading: _isSubmitting,
                onPressed: _register,
              ),
              const SizedBox(height: 8),
              AuthInlineAction(
                prompt: 'Already have an account?',
                actionLabel: 'Sign in',
                onPressed: _isSubmitting ? null : _returnToSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
