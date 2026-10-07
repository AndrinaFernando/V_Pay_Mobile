import 'vpay_user_profile.dart';

enum UserProfileStatus { exists, missing }

class UserProfileResult {
  const UserProfileResult._(this.status, this.user);

  factory UserProfileResult.found(VPayUserProfile user) =>
      UserProfileResult._(UserProfileStatus.exists, user);

  const UserProfileResult.missing() : this._(UserProfileStatus.missing, null);

  final UserProfileStatus status;
  final VPayUserProfile? user;
}
