import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../auth_service.dart';
import '../services/user_api_service.dart';
import '../widgets/auth_form_widgets.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.authService,
    required this.userApiService,
    required this.onProfileCompleted,
  });

  final AuthService authService;
  final UserApiService userApiService;
  final VoidCallback onProfileCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  static const _customerRole = 'CUSTOMER';
  static const _merchantRole = 'MERCHANT';
  static const _businessCategories = <String>[
    'Retail',
    'Food & Beverage',
    'Services',
    'Healthcare',
    'Education',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();

  late final TextEditingController _emailController;
  late final bool _emailUnavailable;

  String _selectedRole = _customerRole;
  String? _businessCategory;
  String? _requestError;
  bool _isSubmitting = false;

  bool get _isMerchant => _selectedRole == _merchantRole;

  @override
  void initState() {
    super.initState();
    final email = widget.authService.currentUser?.email?.trim() ?? '';
    _emailController = TextEditingController(text: email);
    _emailUnavailable = email.isEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    if (_isSubmitting || role == _selectedRole) return;

    setState(() {
      _selectedRole = role;
      _requestError = null;
    });
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return _isMerchant
          ? 'Contact person name is required.'
          : 'Full name is required.';
    }
    if (name.length < 2) return 'Name must be at least 2 characters.';
    if (name.length > 80) return 'Name must be 80 characters or fewer.';
    return null;
  }

  String? _validateEmail(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Your account email is unavailable. Please sign in again.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Mobile number is required.';

    final compact = phone.replaceAll(RegExp(r'[\s-]'), '');
    final isLocal = RegExp(r'^07\d{8}$').hasMatch(compact);
    final isInternational = RegExp(r'^\+947\d{8}$').hasMatch(compact);
    if (!isLocal && !isInternational) {
      return 'Enter a valid Sri Lankan mobile number.';
    }
    return null;
  }

  String? _validateBusinessName(String? value) {
    final businessName = value?.trim() ?? '';
    if (businessName.isEmpty) return 'Business name is required.';
    if (businessName.length < 2) {
      return 'Business name must be at least 2 characters.';
    }
    if (businessName.length > 100) {
      return 'Business name must be 100 characters or fewer.';
    }
    return null;
  }

  String? _validateBusinessCategory(String? value) {
    if (value == null || !_businessCategories.contains(value)) {
      return 'Choose a business category.';
    }
    return null;
  }

  String? _validateBusinessAddress(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) return 'Business address is required.';
    if (address.length < 5) {
      return 'Business address must be at least 5 characters.';
    }
    if (address.length > 200) {
      return 'Business address must be 200 characters or fewer.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_emailUnavailable ||
        (widget.authService.currentUser?.email?.trim().isEmpty ?? true)) {
      setState(() {
        _requestError =
            'Your account email is unavailable. Please sign in again.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _requestError = null;
    });

    try {
      await widget.userApiService.bootstrapUser(
        name: _nameController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        businessName: _isMerchant ? _businessNameController.text : null,
        businessCategory: _isMerchant ? _businessCategory : null,
        businessAddress: _isMerchant ? _businessAddressController.text : null,
      );

      if (!mounted) return;
      widget.onProfileCompleted();
    } on ApiException catch (error) {
      _showError(_messageForApiException(error));
    } on SocketException {
      _showError(
        "We couldn't complete your VPay profile. "
        'Check your connection and try again.',
      );
    } on http.ClientException {
      _showError(
        "We couldn't complete your VPay profile. "
        'Check your connection and try again.',
      );
    } on TimeoutException {
      _showError(
        "We couldn't complete your VPay profile. "
        'Check your connection and try again.',
      );
    } on StateError {
      _showError('Your session has expired. Please sign in again.');
    } catch (_) {
      _showError('Something went wrong while setting up your VPay account.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _messageForApiException(ApiException error) {
    return switch (error.statusCode) {
      400 => error.message,
      401 => 'Your session has expired. Please sign in again.',
      403 => 'Please verify your email before completing your VPay profile.',
      409 => 'This VPay account is already configured with a different account type.',
      _ => 'Something went wrong while setting up your VPay account.',
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _requestError = message);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      title: 'Set up your VPay account',
      subtitle: 'Choose how you will use VPay and complete your details.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Account type',
              style: TextStyle(
                color: vPayInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _RoleSelector(
              selectedRole: _selectedRole,
              enabled: !_isSubmitting,
              onSelected: _selectRole,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: authInputDecoration(
                _isMerchant ? 'Contact person name' : 'Full name',
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              readOnly: true,
              keyboardType: TextInputType.emailAddress,
              decoration: authInputDecoration(
                'Email',
                suffixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.phone,
              textInputAction: _isMerchant
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: authInputDecoration('Mobile number'),
              validator: _validatePhone,
              onFieldSubmitted: _isMerchant ? null : (_) => _submit(),
            ),
            if (_isMerchant) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: authInputDecoration('Business name'),
                validator: _validateBusinessName,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _businessCategory,
                decoration: authInputDecoration('Business category'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: _businessCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _businessCategory = value),
                validator: _validateBusinessCategory,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessAddressController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.streetAddress,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                minLines: 2,
                maxLines: 3,
                decoration: authInputDecoration('Business address'),
                validator: _validateBusinessAddress,
              ),
            ],
            if (_emailUnavailable) ...[
              const SizedBox(height: 16),
              const AuthErrorMessage(
                'Your account email is unavailable. Please sign in again.',
              ),
            ],
            if (_requestError != null && !_emailUnavailable) ...[
              const SizedBox(height: 16),
              AuthErrorMessage(_requestError!),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Complete profile',
              onPressed: _emailUnavailable ? null : _submit,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your email is linked securely to your verified VPay account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: vPayMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onSelected,
  });

  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _option(
            label: 'Customer',
            role: _CompleteProfileScreenState._customerRole,
          ),
          _option(
            label: 'Merchant',
            role: _CompleteProfileScreenState._merchantRole,
          ),
        ],
      ),
    );
  }

  Widget _option({required String label, required String role}) {
    final selected = selectedRole == role;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label account',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onSelected(role) : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? vPayBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : vPayMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
