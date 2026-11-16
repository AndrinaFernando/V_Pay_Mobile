import 'dart:async';
import 'dart:convert';

import '../network/api_client.dart';

enum NotificationType { topUpSuccess, paymentSuccess, paymentReceived }

NotificationType? notificationType(Object? value) => switch (value) {
  'TOP_UP_SUCCESS' => NotificationType.topUpSuccess,
  'PAYMENT_SUCCESS' => NotificationType.paymentSuccess,
  'PAYMENT_RECEIVED' => NotificationType.paymentReceived,
  _ => null,
};

enum RegistrationResult {
  registered,
  denied,
  unavailable,
  unauthorized,
  missingProfile,
  failed,
}

class NotificationService {
  NotificationService({
    required this.requestPermission,
    required this.getToken,
    required this.tokenChanges,
    required this.foregroundMessages,
    required this.openedMessages,
    required this.initialMessage,
    required this.isCurrentSession,
    required this.registerToken,
    this.acceptMessage,
  });

  final Future<bool> Function() requestPermission;
  final Future<String?> Function() getToken;
  final Stream<String> tokenChanges;
  final Stream<Object?> foregroundMessages;
  final Stream<Object?> openedMessages;
  final Future<Object?> Function() initialMessage;
  final bool Function() isCurrentSession;
  final Future<RegistrationResult> Function(String) registerToken;
  final bool Function(Object?)? acceptMessage;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  void Function(NotificationType, bool)? _onMessage;
  void detachMessages() => _onMessage = null;
  bool _disposed = false;
  bool _started = false;
  String? _successfulToken;
  Future<RegistrationResult> _tail = Future.value(
    RegistrationResult.unavailable,
  );
  int _tokenRevision = 0;
  String? _latestRefresh;
  Future<RegistrationResult>? _recovery;
  bool _permissionGranted = false;
  bool get _active => !_disposed && isCurrentSession();

  Future<RegistrationResult> start({
    required void Function(NotificationType, bool opened) onMessage,
  }) async {
    if (!_active) return RegistrationResult.unavailable;
    _onMessage = onMessage;
    if (_started) return recover();
    _started = true;
    void receive(Object? value, bool opened) {
      if (acceptMessage != null && !acceptMessage!(value)) return;
      final type = notificationType(value is Map ? value['type'] : value);
      if (_active && type != null) _onMessage?.call(type, opened);
    }

    try {
      _subscriptions.add(
        foregroundMessages.listen(
          (v) => receive(v, false),
          onError: (Object _) {},
        ),
      );
      _subscriptions.add(
        openedMessages.listen((v) => receive(v, true), onError: (Object _) {}),
      );
      try {
        receive(await initialMessage(), true);
      } catch (_) {}
      if (!_active) return RegistrationResult.unavailable;
      _subscriptions.add(
        tokenChanges.listen((token) {
          if (!_active) return;
          _tokenRevision++;
          _latestRefresh = token;
          if (_permissionGranted) {
            unawaited(_register(token));
          } else {
            unawaited(recover());
          }
        }, onError: (Object _) {}),
      );
      return await recover();
    } catch (_) {
      return RegistrationResult.failed;
    }
  }

  /// One attempt per explicit recovery trigger; never prompts or loops.
  Future<RegistrationResult> recover() {
    if (!_active) {
      return Future.value(RegistrationResult.unavailable);
    }
    return _recovery ??= _recover().whenComplete(() => _recovery = null);
  }

  Future<RegistrationResult> _recover() async {
    final revision = _tokenRevision;
    try {
      if (!_permissionGranted) {
        _permissionGranted = await requestPermission();
        if (!_permissionGranted) return RegistrationResult.denied;
      }
      if (!_active) return RegistrationResult.unavailable;
      final snapshot = await getToken();
      final token = revision == _tokenRevision ? snapshot : _latestRefresh;
      // A refresh event is newer than the snapshot requested by getToken().
      if (!_active || token == null) {
        return RegistrationResult.unavailable;
      }
      return await _register(token);
    } catch (_) {
      return RegistrationResult.failed;
    }
  }

  Future<RegistrationResult> _register(String token) {
    if (!_active || token.isEmpty) {
      return Future.value(RegistrationResult.unavailable);
    }
    // FIFO requests cannot complete out of order. Check identity again at send.
    return _tail = _tail.then((_) async {
      if (!_active) return RegistrationResult.unavailable;
      if (token == _successfulToken) return RegistrationResult.registered;
      try {
        final result = await registerToken(token);
        if (!_active) return RegistrationResult.unavailable;
        if (result == RegistrationResult.registered) _successfulToken = token;
        return result;
      } catch (_) {
        return RegistrationResult.failed;
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}

class NotificationTokenApi {
  NotificationTokenApi(this.client);
  final ApiClient client;
  String? bindingId;

  Future<RegistrationResult> register(String token) async {
    try {
      final response = await client.authenticatedPost(
        '/api/notifications/token',
        body: {'fcmToken': token},
      );
      if (response.statusCode == 401) return RegistrationResult.unauthorized;
      if (response.statusCode == 404) return RegistrationResult.missingProfile;
      if (response.statusCode == 200 &&
          jsonDecode(response.body)['success'] == true) {
        final data = jsonDecode(response.body)['data'];
        bindingId = data is Map && data['bindingId'] is String
            ? data['bindingId'] as String
            : null;
        if (bindingId == null ||
            !RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(bindingId!)) {
          bindingId = null;
          return RegistrationResult.failed;
        }
        return RegistrationResult.registered;
      }
      return RegistrationResult.failed;
    } on StateError {
      return RegistrationResult.unauthorized;
    } catch (_) {
      return RegistrationResult.failed;
    }
  }

  Future<void> unregister(String token, String bindingId) async {
    await client.authenticatedDelete(
      '/api/notifications/token',
      body: {'fcmToken': token, 'bindingId': bindingId},
    );
  }
}
