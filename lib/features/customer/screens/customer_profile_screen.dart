import 'package:flutter/material.dart';

import '../../auth/models/vpay_user_profile.dart';

const _blue = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF767676);
const _line = Color(0xFFEBEBEB);

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.isSigningOut = false,
  });

  final VPayUserProfile profile;
  final VoidCallback onSignOut;
  final bool isSigningOut;

  String _display(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final status = profile.status == 'ACTIVE'
        ? 'Active'
        : _display(profile.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF002B60),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFF0072DC),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _display(profile.name),
                      key: const ValueKey('customerProfileName'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'VPay customer',
                      style: TextStyle(color: Color(0xFFCADCF1), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Account details',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _detail(Icons.mail_outline_rounded, 'Email', profile.email),
              const Divider(height: 1, indent: 56, color: _line),
              _detail(Icons.call_outlined, 'Phone', profile.phone),
              const Divider(height: 1, indent: 56, color: _line),
              _detail(Icons.verified_user_outlined, 'Account status', status),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('customerProfileSignOut'),
          onPressed: isSigningOut ? null : onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(isSigningOut ? 'Signing out...' : 'Sign Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _blue),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  _display(value),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
