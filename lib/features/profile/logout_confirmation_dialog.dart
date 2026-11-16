import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'vpay_colors.dart';

/// Confirms logout and keeps authentication progress and retry feedback modal.
Future<bool> showLogoutConfirmationDialog(
  BuildContext context, {
  required AuthService authService,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LogoutConfirmationDialog(authService: authService),
      ) ??
      false;
}

class _LogoutConfirmationDialog extends StatefulWidget {
  const _LogoutConfirmationDialog({required this.authService});

  final AuthService authService;

  @override
  State<_LogoutConfirmationDialog> createState() =>
      _LogoutConfirmationDialogState();
}

class _LogoutConfirmationDialogState extends State<_LogoutConfirmationDialog> {
  bool _isSigningOut = false;
  String? _error;

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() {
      _isSigningOut = true;
      _error = null;
    });
    try {
      await widget.authService.signOut();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = 'Unable to log out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonHeight =
        48.0 + (MediaQuery.textScalerOf(context).scale(15) - 15).clamp(0, 60);
    return PopScope(
      canPop: !_isSigningOut,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: VPayColors.canvas,
        surfaceTintColor: Colors.transparent,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: const Text(
          'Log out?',
          style: TextStyle(
            color: VPayColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to log out of your VPay account?',
              style: TextStyle(
                color: VPayColors.secondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (_isSigningOut) ...[
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: const Text('Logging out…')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: VPayColors.error),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: TextButton(
                    key: const Key('logoutCancelButton'),
                    onPressed: _isSigningOut
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: VPayColors.divider,
                      foregroundColor: const Color(0xFF484848),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: TextButton(
                    key: const Key('logoutConfirmButton'),
                    onPressed: _isSigningOut ? null : _signOut,
                    style: TextButton.styleFrom(
                      backgroundColor: VPayColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSigningOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const FittedBox(
                            child: Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
