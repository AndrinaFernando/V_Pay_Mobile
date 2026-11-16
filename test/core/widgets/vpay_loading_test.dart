import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/widgets/loading/vpay_loading.dart';
import 'package:vpay_mobile/features/auth/models/vpay_user_profile.dart';
import 'package:vpay_mobile/features/card/models/vpay_card.dart';
import 'package:vpay_mobile/features/card/services/card_api_service.dart';
import 'package:vpay_mobile/features/customer/screens/customer_home_screen.dart';

const _profile = VPayUserProfile(
  uid: 'c1',
  name: 'Nimal Perera',
  email: 'nimal@example.test',
  role: 'CUSTOMER',
  status: 'ACTIVE',
);

class _PendingCardService extends CardApiService {
  final pending = Completer<VPayCard>();

  @override
  Future<VPayCard> getCurrentUserCard() => pending.future;
}

void main() {
  testWidgets('card skeleton is replaced by real content', (tester) async {
    final service = _PendingCardService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerHomeScreen(profile: _profile, cardApiService: service),
        ),
      ),
    );
    expect(find.byKey(const Key('cardSkeleton')), findsOneWidget);
    expect(find.byType(VPaySkeleton), findsNWidgets(2));
    service.pending.complete(
      VPayCard.fromJson({
        'id': 'c1',
        'balance': 1250,
        'maskedNumber': '**** 1234',
        'status': 'ACTIVE',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSkeleton')), findsNothing);
    expect(find.text('Rs. 1,250.00'), findsOneWidget);
  });

  testWidgets('shimmer animates, respects reduced motion, and disposes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VPaySkeleton(height: 40))),
    );
    final before = tester
        .widget<Container>(find.byType(Container).last)
        .decoration;
    await tester.pump(const Duration(milliseconds: 250));
    final after = tester
        .widget<Container>(find.byType(Container).last)
        .decoration;
    expect(before, isNot(equals(after)));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: VPaySkeleton(height: 40)),
        ),
      ),
    );
    final staticDecoration =
        tester.widget<Container>(find.byType(Container).last).decoration
            as BoxDecoration;
    expect(staticDecoration.gradient, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('processing indicator is a linear progress bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VPayProcessingIndicator(label: 'Saving profile')),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
