import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/app_access_gate.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/auth/services/user_api_service.dart';
import 'package:vpay_mobile/features/auth/vpay_account_gate.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserApiService implements UserApiService {
  _FakeUserApiService(this.profileResult);

  final UserProfileResult profileResult;

  @override
  Future<UserProfileResult> getCurrentUserProfile() async => profileResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VPayUserProfile _profile(String role) => VPayUserProfile(
  uid: 'user-$role',
  name: 'Test User',
  email: 'user@example.test',
  role: role,
  status: 'ACTIVE',
  businessName: role == 'MERCHANT' ? 'Test Merchant' : null,
);

Future<Widget> _buildRoleGate(WidgetTester tester, String role) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VPayAccountGate(
        authService: _FakeAuthService(),
        userApiService: _FakeUserApiService(
          UserProfileResult.found(_profile(role)),
        ),
      ),
    ),
  );
  await tester.pump();

  final gate = tester.widget<AppAccessGate>(find.byType(AppAccessGate));
  return gate.child;
}

void main() {
  testWidgets('routes CUSTOMER profiles to the existing customer shell', (
    tester,
  ) async {
    final child = await _buildRoleGate(tester, 'CUSTOMER');

    expect(child, isA<CustomerShell>());
    expect(find.byType(MerchantDashboardScreen), findsNothing);
  });

  testWidgets('routes MERCHANT profiles to the merchant dashboard', (
    tester,
  ) async {
    final child = await _buildRoleGate(tester, 'MERCHANT');

    expect(child, isA<MerchantDashboardScreen>());
    expect(find.byType(CustomerShell), findsNothing);
  });
}
