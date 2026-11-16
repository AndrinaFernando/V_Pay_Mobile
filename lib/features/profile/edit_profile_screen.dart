import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_exception.dart';
import '../auth/models/vpay_user_profile.dart';
import '../auth/services/user_api_service.dart';
import 'vpay_colors.dart';

/// Edits only the fields permitted for the role returned by the backend.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    this.userApiService,
  });

  final VPayUserProfile profile;
  final UserApiService? userApiService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _categories = <String>[
    'Retail',
    'Food & Beverage',
    'Services',
    'Healthcare',
    'Education',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _businessName;
  late final TextEditingController _businessAddress;
  String? _category;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;

  bool get _merchant => widget.profile.role.toUpperCase() == 'MERCHANT';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _email = TextEditingController(text: widget.profile.email);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
    _businessName = TextEditingController(
      text: widget.profile.businessName ?? '',
    );
    _businessAddress = TextEditingController(
      text: widget.profile.businessAddress ?? '',
    );
    final initialCategory = widget.profile.businessCategory;
    _category = _categories.contains(initialCategory) ? initialCategory : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _businessName.dispose();
    _businessAddress.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text != widget.profile.name ||
      _phone.text != (widget.profile.phone ?? '') ||
      (_merchant &&
          (_businessName.text != (widget.profile.businessName ?? '') ||
              _businessAddress.text != (widget.profile.businessAddress ?? '') ||
              _category != widget.profile.businessCategory));

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved profile changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard Changes'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _merchant
          ? 'Contact person name is required.'
          : 'Full name is required.';
    }
    if (text.length < 2) return 'Name must be at least 2 characters.';
    if (text.length > 80) return 'Name must be 80 characters or fewer.';
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mobile number is required.';
    final compact = text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(07\d{8}|\+947\d{8})$').hasMatch(compact)) {
      return 'Enter a valid Sri Lankan mobile number.';
    }
    return null;
  }

  String? _validateBusinessName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Business name is required.';
    if (text.length < 2) return 'Business name must be at least 2 characters.';
    if (text.length > 100) {
      return 'Business name must be 100 characters or fewer.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Business address is required.';
    if (text.length < 5) {
      return 'Business address must be at least 5 characters.';
    }
    if (text.length > 200) {
      return 'Business address must be 200 characters or fewer.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await (widget.userApiService ?? UserApiService())
          .updateCurrentUserProfile(
            name: _name.text,
            phone: _phone.text,
            businessName: _merchant ? _businessName.text : null,
            businessCategory: _merchant ? _category : null,
            businessAddress: _merchant ? _businessAddress.text : null,
          );
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _saving = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        400 => error.message,
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Email verification is required before editing your profile.',
        404 => 'Your profile could not be found. Please try again later.',
        _ => 'Could not save your profile. Please try again.',
      };
    }
    if (error is SocketException || error is http.ClientException) {
      return 'No connection to VPay. Check your internet and try again.';
    }
    if (error is StateError) {
      return 'Please sign in again to edit your profile.';
    }
    return 'Could not save your profile. Please try again.';
  }

  InputDecoration _decoration(String label, {bool locked = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: VPayColors.canvas,
        suffixIcon: locked
            ? const Icon(Icons.lock_outline_rounded, size: 20)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: VPayColors.divider),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: VPayColors.surface,
        appBar: AppBar(
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: BackButton(onPressed: _leave),
          backgroundColor: VPayColors.canvas,
          foregroundColor: VPayColors.ink,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: VPayColors.divider),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VPayColors.canvas,
                    border: Border.all(color: VPayColors.divider),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('editName'),
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          _merchant ? "Contact Person's Name" : 'Full Name',
                        ),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('editEmail'),
                        controller: _email,
                        readOnly: true,
                        decoration: _decoration('Email Address', locked: true),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('editPhone'),
                        controller: _phone,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration('Mobile Number'),
                        validator: _validatePhone,
                      ),
                      if (_merchant) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('editBusinessName'),
                          controller: _businessName,
                          enabled: !_saving,
                          decoration: _decoration('Business Name'),
                          validator: _validateBusinessName,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const Key('editBusinessCategory'),
                          initialValue: _category,
                          decoration: _decoration('Business Category'),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _category = value),
                          validator: (value) => _categories.contains(value)
                              ? null
                              : 'Choose a business category.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('editBusinessAddress'),
                          controller: _businessAddress,
                          enabled: !_saving,
                          minLines: 2,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          decoration: _decoration('Business Address'),
                          validator: _validateAddress,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    key: const Key('editSaveError'),
                    style: const TextStyle(color: VPayColors.error),
                  ),
                ],
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttons = [
                      OutlinedButton(
                        key: const Key('editCancel'),
                        onPressed: _saving ? null : _leave,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: VPayColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        key: const Key('editSave'),
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: VPayColors.electric,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ];
                    if (constraints.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buttons[1],
                          const SizedBox(height: 12),
                          buttons[0],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 12),
                        Expanded(child: buttons[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
