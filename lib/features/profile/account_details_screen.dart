import 'package:flutter/material.dart';

import '../auth/models/vpay_user_profile.dart';
import 'vpay_colors.dart';

/// Read-only Account Details screen shared by both Customer and Merchant.
///
/// Displays all available profile fields. Merchant-specific fields
/// (business name, category, address) appear only when the user role is
/// MERCHANT. Missing values show "Not provided".
class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key, required this.profile});

  final VPayUserProfile profile;

  String _display(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  bool get _isMerchant => profile.role.trim().toUpperCase() == 'MERCHANT';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VPayColors.surface,
      appBar: AppBar(
        title: const Text(
          'Account Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: VPayColors.ink,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: VPayColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: VPayColors.divider),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _buildSection([
              _DetailRow(
                label: _isMerchant ? "Contact Person's Name" : 'Full Name',
                value: _display(profile.name),
                icon: Icons.person_outline_rounded,
              ),
              _DetailRow(
                label: 'Email Address',
                value: _display(profile.email),
                icon: Icons.mail_outline_rounded,
              ),
              _DetailRow(
                label: 'Mobile Number',
                value: _display(profile.phone),
                icon: Icons.phone_outlined,
              ),
              _DetailRow(
                label: 'Account Type',
                value: _isMerchant ? 'Merchant' : 'Customer',
                icon: Icons.badge_outlined,
              ),
              _DetailRow(
                label: 'Account Status',
                value: _display(profile.status),
                icon: Icons.verified_outlined,
                isLast: !_isMerchant,
              ),
              if (_isMerchant) ...[
                _DetailRow(
                  label: 'Business Name',
                  value: _display(profile.businessName),
                  icon: Icons.store_outlined,
                ),
                _DetailRow(
                  label: 'Business Category',
                  value: _display(profile.businessCategory),
                  icon: Icons.category_outlined,
                ),
                _DetailRow(
                  label: 'Business Address',
                  value: _display(profile.businessAddress),
                  icon: Icons.location_on_outlined,
                  isLast: true,
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VPayColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isLast = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: VPayColors.electric.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: VPayColors.electric, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: VPayColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: VPayColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: VPayColors.divider,
            indent: 72,
          ),
      ],
    );
  }
}
