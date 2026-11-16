/// Only the current authenticated registration may trigger an in-app refresh.
/// A new process has no trusted binding until it registers again.
class NotificationBinding {
  static String? uid;
  static String? token;
  static String? id;

  static void set(String userId, String fcmToken, String bindingId) {
    uid = userId;
    token = fcmToken;
    id = bindingId;
  }

  static bool matches(String? userId, Object? bindingId) =>
      userId != null && uid == userId && id != null && id == bindingId;

  static void clear() {
    uid = null;
    token = null;
    id = null;
  }
}
