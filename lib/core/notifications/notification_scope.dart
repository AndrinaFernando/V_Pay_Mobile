import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/auth/auth_service.dart';
import 'firebase_notifications.dart';
import 'notification_service.dart';
import 'notification_open_coordinator.dart';

/// Mounted only after profile initialization and the existing device access gate.
class NotificationScope extends StatefulWidget {
  const NotificationScope({
    super.key,
    required this.auth,
    required this.child,
    required this.role,
    this.opens,
    this.serviceFactory,
    this.retainService = false,
  });
  final NotificationOpenCoordinator? opens;
  final NotificationService Function(AuthService)? serviceFactory;
  final bool retainService;
  final AuthService auth;
  final Widget child;
  final String role;
  @override
  State<NotificationScope> createState() => _NotificationScopeState();
}

class _NotificationScopeState extends State<NotificationScope>
    with WidgetsBindingObserver {
  NotificationService? _service;
  int _revision = 0;
  int? _sessionVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionVersion = widget.opens?.sessionVersion;
    widget.opens?.addListener(_pendingOpen);
    _pendingOpen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (widget.serviceFactory == null &&
              (kIsWeb || defaultTargetPlatform != TargetPlatform.android))) {
        return;
      }
      try {
        _service = (widget.serviceFactory ?? firebaseNotificationService)(
          widget.auth,
        );
        unawaited(_service!.start(onMessage: _message));
      } catch (_) {
        /* Push availability must never block the app. */
      }
    });
  }

  void _pendingOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final type = widget.opens?.take(
        widget.role,
        sessionVersion: _sessionVersion,
      );
      if (type != null) _message(type, true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_service?.recover());
    }
  }

  void _refresh() {
    if (!mounted) return;
    // Recreate the existing role home, which loads authoritative API data.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _revision++);
  }

  void _message(NotificationType type, bool opened) {
    if (!mounted) return;
    if ((type == NotificationType.paymentReceived) !=
        (widget.role == 'MERCHANT')) {
      return;
    }
    if (opened) {
      _refresh();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'VPay activity update. Refresh to view the latest details.',
        ),
        action: SnackBarAction(label: 'Refresh', onPressed: _refresh),
      ),
    );
  }

  @override
  void dispose() {
    widget.opens?.removeListener(_pendingOpen);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.retainService) {
      _service?.detachMessages();
    } else {
      _service?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_revision), child: widget.child);
}
