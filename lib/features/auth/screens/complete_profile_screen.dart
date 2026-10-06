import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../services/user_api_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.userApiService,
    required this.onProfileCompleted,
  });

  final UserApiService userApiService;
  final VoidCallback onProfileCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  static const _blue = Color(0xFF0072DC);
  static const _ink = Color(0xFF222222);
  static const _muted = Color(0xFF484848);
  static const _networkError =
      "We couldn't complete your VPay profile. Check your connection and try again.";

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedRole;
  String? _roleError;
  String? _requestError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final validName = _formKey.currentState?.validate() ?? false;
    setState(() {
      _roleError = _selectedRole == null ? 'Choose an account type.' : null;
      _requestError = null;
    });
    if (!validName || _selectedRole == null) return;

    final name = _nameController.text.trim();
    _nameController.value = _nameController.value.copyWith(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() => _isSubmitting = true);

    try {
      await widget.userApiService.bootstrapUser(
        name: name,
        role: _selectedRole!,
      );
      if (mounted) widget.onProfileCompleted();
    } on ApiException catch (error) {
      if (mounted) setState(() => _requestError = _apiErrorMessage(error));
    } on SocketException catch (_) {
      if (mounted) setState(() => _requestError = _networkError);
    } on http.ClientException catch (_) {
      if (mounted) setState(() => _requestError = _networkError);
    } on TimeoutException catch (_) {
      if (mounted) setState(() => _requestError = _networkError);
    } on StateError catch (_) {
      if (mounted) {
        setState(
          () =>
              _requestError = 'Your session has expired. Please sign in again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _requestError =
              'Something went wrong while setting up your VPay account.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _apiErrorMessage(ApiException error) => switch (error.statusCode) {
    401 => 'Your session has expired. Please sign in again.',
    403 => 'Please verify your email before completing your VPay profile.',
    409 =>
      'This VPay account is already configured with a different account type.',
    _ => 'Something went wrong while setting up your VPay account.',
  };

  Widget _roleTile(
    String role,
    String title,
    String description,
    IconData icon,
  ) {
    final selected = _selectedRole == role;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFEAF4FF) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _isSubmitting
              ? null
              : () => setState(() {
                  _selectedRole = role;
                  _roleError = null;
                  _requestError = null;
                }),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? _blue : const Color(0xFFEBEBEB),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: selected ? _blue : const Color(0xFF01397C)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? _blue : const Color(0xFF767676),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'VPay',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        border: Border.all(color: const Color(0xFFEBEBEB)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 32,
                        color: Color(0xFF01397C),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Complete your VPay profile',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your email is verified. Add your name and choose how you will use VPay.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Enter your full name',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _blue),
                        ),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter your full name.'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Account type',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _roleTile(
                      'CUSTOMER',
                      'Customer',
                      'Top up, pay merchants and manage your virtual card.',
                      Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    _roleTile(
                      'MERCHANT',
                      'Merchant',
                      'Accept VPay payments and manage your merchant account.',
                      Icons.storefront_outlined,
                    ),
                    if (_roleError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _roleError!,
                        style: const TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ],
                    if (_requestError != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _requestError!,
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Complete profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
