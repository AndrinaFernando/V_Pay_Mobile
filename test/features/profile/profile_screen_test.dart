import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/auth_service.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/profile/account_details_screen.dart';
import 'package:vpay_mobile/features/profile/edit_profile_screen.dart';
import 'package:vpay_mobile/features/profile/profile_screen.dart';
import 'package:vpay_mobile/features/profile/vpay_colors.dart';

const _customer = VPayUserProfile(
  uid: 'cust-1',
  name: 'Nimal Perera',
  email: 'nimal@university.test',
  role: 'CUSTOMER',
  status: 'ACTIVE',
  phone: '+94771112233',
);

const _merchant = VPayUserProfile(
  uid: 'merch-1',
  name: 'Kamani Silva',
  email: 'kamani@business.test',
  role: 'MERCHANT',
  status: 'ACTIVE',
  phone: '+94779998877',
  businessName: 'Campus Cafe',
  businessCategory: 'Food & Beverage',
  businessAddress: '5 University Lane',
);

class _FakeAuthService implements AuthService {
  Object? signOutError;
  Completer<void>? pending;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _profileApp(
  VPayUserProfile profile, {
  _FakeAuthService? auth,
  double scale = 1,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: ProfileScreen(
      profile: profile,
      authService: auth ?? _FakeAuthService(),
    ),
  );
}

Future<void> _tapMenu(WidgetTester tester, String key) async {
  final item = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    item,
    150,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('profileScrollView')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  for (final profile in [_customer, _merchant]) {
    final merchant = profile.role == 'MERCHANT';
    group(profile.role, () {
      testWidgets('profile renders identity, initials, role and menu', (
        tester,
      ) async {
        await tester.pumpWidget(_profileApp(profile));
        expect(find.text(profile.name), findsOneWidget);
        expect(find.text(profile.email), findsOneWidget);
        expect(find.text(profile.role), findsOneWidget);
        expect(find.text(merchant ? 'KS' : 'NP'), findsOneWidget);
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(
          find.byKey(const Key('profileBusinessName')),
          merchant ? findsOneWidget : findsNothing,
        );
      });

      testWidgets('Account Details opens with role-specific read-only fields', (
        tester,
      ) async {
        await tester.pumpWidget(_profileApp(profile));
        await _tapMenu(tester, 'profileAccountDetails');
        expect(find.byType(AccountDetailsScreen), findsOneWidget);
        expect(
          find.text(merchant ? "Contact Person's Name" : 'Full Name'),
          findsOneWidget,
        );
        expect(find.text(profile.name), findsOneWidget);
        expect(find.text(profile.email), findsOneWidget);
        expect(find.text(profile.phone!), findsOneWidget);
        expect(find.text(merchant ? 'Merchant' : 'Customer'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        if (merchant) {
          expect(find.text('Campus Cafe'), findsOneWidget);
          expect(find.text('Food & Beverage'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('5 University Lane'), 150);
          expect(find.text('5 University Lane'), findsOneWidget);
        } else {
          expect(find.text('Business Name'), findsNothing);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
      });

      final pages = {
        'profileHelpCenter': ['Help Center', 'Help & Support'],
        'profileAboutVPay': ['About VPay', 'What is VPay?'],
        'profileTerms': ['Terms & Conditions', 'Using the prototype'],
        'profilePrivacy': ['Privacy Policy', 'Account information'],
      };
      for (final page in pages.entries) {
        testWidgets('${page.value.first} opens and back returns to profile', (
          tester,
        ) async {
          await tester.pumpWidget(_profileApp(profile));
          await _tapMenu(tester, page.key);
          expect(find.text(page.value.first), findsOneWidget);
          expect(find.text(page.value.last), findsOneWidget);
          if (page.key == 'profileTerms' || page.key == 'profilePrivacy') {
            expect(find.textContaining('Draft'), findsOneWidget);
            expect(find.textContaining('approval'), findsOneWidget);
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(ProfileScreen), findsOneWidget);
        });
      }

      testWidgets('Edit Profile opens the shared form', (tester) async {
        await tester.pumpWidget(_profileApp(profile));
        await _tapMenu(tester, 'profileEditProfile');
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(find.byKey(const Key('editName')), findsOneWidget);
        expect(
          find.byKey(const Key('editBusinessName')),
          merchant ? findsOneWidget : findsNothing,
        );
        await tester.ensureVisible(find.byKey(const Key('editCancel')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('editCancel')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
      });

      testWidgets('logout dialog opens and Cancel preserves the session', (
        tester,
      ) async {
        final auth = _FakeAuthService();
        await tester.pumpWidget(_profileApp(profile, auth: auth));
        await _tapMenu(tester, 'profileLogout');
        expect(find.text('Log out?'), findsOneWidget);
        expect(
          find.text('Are you sure you want to log out of your VPay account?'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('logoutCancelButton')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(auth.signOutCalls, 0);
      });

      testWidgets('confirming logout invokes AuthService once while pending', (
        tester,
      ) async {
        final auth = _FakeAuthService()..pending = Completer<void>();
        await tester.pumpWidget(_profileApp(profile, auth: auth));
        await _tapMenu(tester, 'profileLogout');
        final confirm = find.byKey(const Key('logoutConfirmButton'));
        await tester.tap(confirm);
        await tester.tap(confirm);
        await tester.pump();
        expect(auth.signOutCalls, 1);
        expect(find.text('Logging out…'), findsOneWidget);
        expect(tester.widget<TextButton>(confirm).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(find.byKey(const Key('logoutCancelButton')))
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        auth.pending!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('sign-out failure displays feedback and supports retry', (
        tester,
      ) async {
        final auth = _FakeAuthService()..signOutError = StateError('network');
        await tester.pumpWidget(_profileApp(profile, auth: auth));
        await _tapMenu(tester, 'profileLogout');
        await tester.tap(find.byKey(const Key('logoutConfirmButton')));
        await tester.pumpAndSettle();
        expect(
          find.text('Unable to log out. Please try again.'),
          findsOneWidget,
        );
        expect(auth.signOutCalls, 1);
        auth.signOutError = null;
        await tester.tap(find.byKey(const Key('logoutConfirmButton')));
        await tester.pumpAndSettle();
        expect(auth.signOutCalls, 2);
        expect(find.byType(AlertDialog), findsNothing);
      });
    });
  }

  testWidgets('missing and whitespace merchant fields display placeholders', (
    tester,
  ) async {
    const incomplete = VPayUserProfile(
      uid: 'm',
      name: ' ',
      email: '',
      role: 'MERCHANT',
      status: ' ',
      phone: ' ',
      businessName: '',
    );
    await tester.pumpWidget(_profileApp(incomplete));
    expect(find.text('?'), findsOneWidget);
    await _tapMenu(tester, 'profileAccountDetails');
    expect(find.text('Not provided'), findsNWidgets(7));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'logout buttons are horizontal, equal and usable at 320px with scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_profileApp(_merchant, scale: scale));
        await _tapMenu(tester, 'profileLogout');
        final cancel = find.byKey(const Key('logoutCancelButton'));
        final confirm = find.byKey(const Key('logoutConfirmButton'));
        final cancelRect = tester.getRect(cancel);
        final confirmRect = tester.getRect(confirm);
        expect(cancelRect.center.dy, confirmRect.center.dy);
        expect(cancelRect.right, lessThan(confirmRect.left));
        expect(cancelRect.height, confirmRect.height);
        expect(cancelRect.height, greaterThanOrEqualTo(48));
        expect(cancel.hitTestable(), findsOneWidget);
        expect(confirm.hitTestable(), findsOneWidget);
        final cancelStyle = tester.widget<TextButton>(cancel).style!;
        final confirmStyle = tester.widget<TextButton>(confirm).style!;
        expect(cancelStyle.backgroundColor!.resolve({}), VPayColors.divider);
        expect(
          cancelStyle.foregroundColor!.resolve({}),
          const Color(0xFF484848),
        );
        expect(confirmStyle.backgroundColor!.resolve({}), VPayColors.error);
        expect(confirmStyle.foregroundColor!.resolve({}), Colors.white);
        expect(tester.takeException(), isNull);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
      },
    );
  }
}
