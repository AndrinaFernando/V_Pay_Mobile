import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../widgets/auth_form_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.authService,
    this.initialEmail = '',
  });

  final AuthService? authService;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final AuthService _authService;
  bool _isSubmitting = false;
  String? _resetError;
  String? _submittedEmail;

  bool get _isComplete => _submittedEmail != null;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
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

  Future<void> _sendResetLink() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    _emailController.value = _emailController.value.copyWith(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
    setState(() {
      _isSubmitting = true;
      _resetError = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) setState(() => _submittedEmail = email);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      if (error.code == 'user-not-found') {
        setState(() => _submittedEmail = email);
      } else {
        setState(() => _resetError = _errorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _resetError =
              'Something went wrong while sending the reset link.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _errorMessage(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' =>
      'Too many reset requests. Please wait and try again later.',
    'network-request-failed' =>
      'Unable to connect. Check your internet connection and try again.',
    _ => 'Something went wrong while sending the reset link.',
  };

  void _returnToSignIn() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      title: _isComplete ? 'Check your email' : 'Reset your password',
      subtitle: _isComplete
          ? 'If an account exists for $_submittedEmail, you’ll receive a password reset link shortly.'
          : 'Enter your email and we’ll send you a secure password reset link.',
      child: _isComplete ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_isSubmitting,
            autofocus: widget.initialEmail.isEmpty,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _sendResetLink(),
            decoration: authInputDecoration('Email'),
            validator: _validateEmail,
          ),
          if (_resetError != null) ...[
            const SizedBox(height: 16),
            AuthErrorMessage(_resetError!),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Send Reset Link',
            isLoading: _isSubmitting,
            onPressed: _sendResetLink,
          ),
          const SizedBox(height: 8),
          AuthInlineAction(
            prompt: 'Remember your password?',
            actionLabel: 'Sign in',
            onPressed: _isSubmitting ? null : _returnToSignIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 72,
            width: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: vPayBlue,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Return to Sign In',
          isLoading: false,
          onPressed: _returnToSignIn,
        ),
      ],
    );
  }
}
