import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class NotificationOpen {
  const NotificationOpen(this.id, this.type);
  final String? id;
  final Object? type;
}

/// Stores only a refresh intent, never payload text or financial data.
/// Events received signed out are deliberately discarded: their owner is unknown.
class NotificationOpenCoordinator extends ChangeNotifier {
  NotificationOpenCoordinator({
    required this.currentUid,
    required Stream<String?> sessions,
    required Stream<NotificationOpen> opened,
    required Future<NotificationOpen?> Function() initial,
  }) {
    _uid = currentUid();
    _subscriptions.add(sessions.listen(_setSession));
    _subscriptions.add(opened.listen(_receive, onError: (Object _) {}));
    final uid = _uid;
    final generation = _generation;
    unawaited(() async {
      try {
        final event = await initial();
        _syncSession();
        if (!_disposed &&
            uid == _uid &&
            generation == _generation &&
            event != null) {
          _receive(event);
        }
      } catch (_) {}
    }());
  }
  final String? Function() currentUid;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  String? _uid;
  int _generation = 0;
  NotificationType? _pending;
  bool _disposed = false;

  void _syncSession() => _setSession(currentUid());

  void _setSession(String? uid) {
    if (_disposed) return;
    if (uid != _uid) {
      _uid = uid;
      _generation++;
      _pending = null;
    }
  }

  void _receive(NotificationOpen event) {
    if (_disposed) return;
    _syncSession();
    final type = notificationType(event.type);
    if (_uid == null || type == null) return;
    final id = event.id;
    if (id != null && !_seen.add(id)) return;
    if (_seen.length > 64) _seen.remove(_seen.first);
    _pending =
        type; // Coalesce multiple locked taps into one authoritative refresh.
    notifyListeners();
  }

  int get sessionVersion {
    _syncSession();
    return _generation;
  }

  NotificationType? take(String role, {int? sessionVersion}) {
    if (_disposed) return null;
    _syncSession();
    if (sessionVersion != null && sessionVersion != _generation) return null;
    final pending = _pending;
    _pending = null;
    if (_uid == null || pending == null) return null;
    final appropriate = role == 'MERCHANT'
        ? pending == NotificationType.paymentReceived
        : role == 'CUSTOMER' && pending != NotificationType.paymentReceived;
    return appropriate ? pending : null;
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
