import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/auth/auth_service.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';
import 'notification_service.dart';
import 'notification_open_coordinator.dart';

@pragma('vm:entry-point')
Future<void> vpayBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Android displays notification payloads. Never duplicate them or change finances.
}

bool _permissionRequested = false;

NotificationOpenCoordinator firebaseNotificationOpens(AuthService auth) {
  NotificationOpen convert(RemoteMessage m) =>
      NotificationOpen(m.messageId, m.data['type']);
  return NotificationOpenCoordinator(
    currentUid: () => auth.currentUser?.uid,
    sessions: auth.authStateChanges().map((user) => user?.uid),
    opened: FirebaseMessaging.onMessageOpenedApp.map(convert),
    initial: () async {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : convert(message);
    },
  );
}

NotificationService firebaseNotificationService(AuthService auth) {
  final uid = auth.currentUser?.uid;
  final messaging = FirebaseMessaging.instance;
  final api = NotificationTokenApi(
    ApiClient(authService: _SessionAuth(auth, uid)),
  );
  return NotificationService(
    requestPermission: () async {
      final prompt = !_permissionRequested;
      _permissionRequested = true;
      final settings = prompt
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    },
    getToken: messaging.getToken,
    tokenChanges: messaging.onTokenRefresh,
    foregroundMessages: FirebaseMessaging.onMessage.map((m) => m.data['type']),
    openedMessages: const Stream.empty(),
    initialMessage: () async => null,
    isCurrentSession: () => uid != null && auth.currentUser?.uid == uid,
    // Bind identity across the asynchronous Firebase ID-token retrieval too.
    registerToken: (token) => api.register(token),
  );
}

class _SessionAuth extends AuthService {
  _SessionAuth(this.source, this.uid);
  final AuthService source;
  final String? uid;
  @override
  Future<String?> getFreshIdToken() async {
    if (uid == null || source.currentUser?.uid != uid) return null;
    final token = await source.getFreshIdToken();
    return source.currentUser?.uid == uid ? token : null;
  }
}
