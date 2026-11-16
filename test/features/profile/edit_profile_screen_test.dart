import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/network/api_exception.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/auth/models/user_profile_result.dart';
import 'package:vpay_mobile/features/auth/services/user_api_service.dart';
import 'package:vpay_mobile/features/customer/screens/customer_shell.dart';
import 'package:vpay_mobile/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:vpay_mobile/features/profile/account_details_screen.dart';
import 'package:vpay_mobile/features/profile/edit_profile_screen.dart';
import 'package:vpay_mobile/features/profile/profile_screen.dart';

import '../../support/fake_dashboard_services.dart';

const customer = VPayUserProfile(
  uid: 'c1',
  name: 'Nimal Perera',
  email: 'nimal@example.test',
  phone: '+94771112233',
  role: 'CUSTOMER',
  status: 'ACTIVE',
);
const merchant = VPayUserProfile(
  uid: 'm1',
  name: 'Amara Perera',
  email: 'amara@example.test',
  phone: '+94771112233',
  role: 'MERCHANT',
  status: 'ACTIVE',
  businessName: 'ABC Grocery',
  businessCategory: 'Retail',
  businessAddress: 'Main Street, Colombo',
);

class FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUpdates implements UserApiService {
  int calls = 0;
  Object? failure;
  Completer<VPayUserProfile>? pending;
  String? lastName;
  String? lastPhone;
  String? lastBusinessName;
  String? lastCategory;
  String? lastAddress;

  @override
  Future<VPayUserProfile> updateCurrentUserProfile({
    String? name,
    String? phone,
    String? businessName,
    String? businessCategory,
    String? businessAddress,
  }) async {
    calls++;
    lastName = name;
    lastPhone = phone;
    lastBusinessName = businessName;
    lastCategory = businessCategory;
    lastAddress = businessAddress;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    final base = businessName == null ? customer : merchant;
    return VPayUserProfile(
      uid: base.uid,
      name: name!,
      email: base.email,
      phone: phone,
      role: base.role,
      status: base.status,
      businessName: businessName,
      businessCategory: businessCategory,
      businessAddress: businessAddress,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> openEditor(
  WidgetTester tester,
  VPayUserProfile profile,
  FakeUpdates service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileScreen(
        profile: profile,
        authService: FakeAuth(),
        userApiService: service,
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('profileEditProfile')));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.ensureVisible(find.byKey(const Key('editSave')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('editSave')));
  await tester.pump();
}

void main() {
  testWidgets(
    'customer form is prefilled, email locked, and validates inputs',
    (tester) async {
      final service = FakeUpdates();
      await openEditor(tester, customer, service);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('editName')))
            .controller!
            .text,
        'Nimal Perera',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('editPhone')))
            .controller!
            .text,
        '+94771112233',
      );
      final email = tester.widget<TextFormField>(
        find.byKey(const Key('editEmail')),
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('editEmail')),
                matching: find.byType(EditableText),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(email.controller!.text, 'nimal@example.test');
      expect(find.byKey(const Key('editBusinessName')), findsNothing);
      await tester.enterText(find.byKey(const Key('editName')), 'N');
      await tester.enterText(find.byKey(const Key('editPhone')), '123');
      await save(tester);
      expect(service.calls, 0);
      expect(find.text('Name must be at least 2 characters.'), findsOneWidget);
      expect(
        find.text('Enter a valid Sri Lankan mobile number.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('editName')), '');
      await save(tester);
      expect(find.text('Full name is required.'), findsOneWidget);
    },
  );

  testWidgets(
    'successful customer save refreshes profile, details and home greeting',
    (tester) async {
      final service = FakeUpdates();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerShell(
            profile: customer,
            authService: FakeAuth(),
            userApiService: service,
            cardApiService: FakeDashboardCardService(),
            transactionService: FakeDashboardTransactionService(),
          ),
        ),
      );
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileEditProfile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('editName')), 'John Silva');
      await save(tester);
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(service.lastBusinessName, isNull);
      expect(find.text('Profile updated successfully.'), findsOneWidget);
      expect(find.text('John Silva'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profileAccountDetails')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailsScreen), findsOneWidget);
      expect(find.text('John Silva'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('John'), findsWidgets);
    },
  );

  testWidgets('cancel and system back warn only about modified values', (
    tester,
  ) async {
    final service = FakeUpdates();
    await openEditor(tester, customer, service);
    await tester.tap(find.byKey(const Key('editCancel')));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(service.calls, 0);
    await tester.tap(find.byKey(const Key('profileEditProfile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('editName')), 'Changed Name');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Continue Editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('editName')))
          .controller!
          .text,
      'Changed Name',
    );
    await tester.tap(find.byKey(const Key('editCancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Nimal Perera'), findsOneWidget);
    expect(service.calls, 0);
  });

  testWidgets(
    'duplicate save is blocked, loading shown, failure retains input for retry',
    (tester) async {
      final service = FakeUpdates()..pending = Completer<VPayUserProfile>();
      await openEditor(tester, customer, service);
      await tester.enterText(find.byKey(const Key('editName')), 'John Silva');
      await save(tester);
      expect(service.calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('editSave')))
            .onPressed,
        isNull,
      );
      service.pending!.completeError(const ApiException(500, 'server trace'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your profile. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('editName')))
            .controller!
            .text,
        'John Silva',
      );
      service.pending = null;
      await save(tester);
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.text('John Silva'), findsOneWidget);
    },
  );

  testWidgets(
    'merchant fields validate and saved business appears on dashboard and details',
    (tester) async {
      final service = FakeUpdates();
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(
            profile: merchant,
            authService: FakeAuth(),
            userApiService: service,
            loadProfile: () async => UserProfileResult.found(merchant),
            merchantBalanceService: FakeDashboardMerchantBalanceService(),
            merchantReceivedPaymentsService:
                FakeDashboardReceivedPaymentsService(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('merchantProfileAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileEditProfile')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('editBusinessName')))
            .controller!
            .text,
        'ABC Grocery',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('editBusinessAddress')))
            .controller!
            .text,
        'Main Street, Colombo',
      );
      await tester.enterText(find.byKey(const Key('editBusinessName')), 'A');
      await tester.enterText(
        find.byKey(const Key('editBusinessAddress')),
        'Abc',
      );
      await save(tester);
      expect(service.calls, 0);
      expect(
        find.text('Business name must be at least 2 characters.'),
        findsOneWidget,
      );
      expect(
        find.text('Business address must be at least 5 characters.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('editBusinessName')),
        'ABC Supermarket',
      );
      await tester.enterText(
        find.byKey(const Key('editBusinessAddress')),
        'New Market Street, Colombo',
      );
      await tester.ensureVisible(find.byKey(const Key('editBusinessCategory')));
      await tester.tap(find.byKey(const Key('editBusinessCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Services').last);
      await tester.pumpAndSettle();
      await save(tester);
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(service.lastCategory, 'Services');
      expect(find.text('ABC Supermarket'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profileAccountDetails')));
      await tester.pumpAndSettle();
      expect(find.text('ABC Supermarket'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('merchantDashboardBusinessDetails')),
            )
            .data,
        contains('ABC Supermarket'),
      );
    },
  );
}
