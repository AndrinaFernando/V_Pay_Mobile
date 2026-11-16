import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/models/user_profile_result.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../auth/services/user_api_service.dart';
import '../../profile/profile_screen.dart';

/// Retains the merchant entry point and its authenticated profile refresh.
class MerchantProfileScreen extends StatelessWidget {
  const MerchantProfileScreen({
    super.key,
    required this.profile,
    required this.authService,
    this.loadProfile,
    this.onBack,
    this.userApiService,
    this.onProfileUpdated,
  });

  final VPayUserProfile profile;
  final AuthService authService;
  final Future<UserProfileResult> Function()? loadProfile;
  final VoidCallback? onBack;
  final UserApiService? userApiService;
  final ValueChanged<VPayUserProfile>? onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(
      profile: profile,
      authService: authService,
      loadProfile: loadProfile ?? UserApiService().getCurrentUserProfile,
      onBack: onBack,
      userApiService: userApiService,
      onProfileUpdated: onProfileUpdated,
    );
  }
}
