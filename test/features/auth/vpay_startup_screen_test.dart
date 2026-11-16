import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/features/auth/screens/vpay_startup_screen.dart';

void main() {
  testWidgets(
    'logo sweep repeats while initialization is pending, then opens app',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VPayStartupGate(
            initialize: () {
              calls++;
              return pending.future;
            },
            child: const Text('Authenticated application'),
          ),
        ),
      );
      expect(calls, 1);
      expect(find.byKey(const Key('startupLogo')), findsOneWidget);
      expect(find.text('Authenticated application'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('startupSweep')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('startupSweep')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.byKey(const Key('startupSweep')), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Authenticated application'), findsOneWidget);
      expect(find.byType(VPayStartupScreen), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initialization failure offers retry without exposing details', (
    tester,
  ) async {
    final retry = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VPayStartupGate(
          initialize: () {
            calls++;
            return calls == 1
                ? Future.error(StateError('secret detail'))
                : retry.future;
          },
          child: const Text('Ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('VPay could not start'), findsOneWidget);
    expect(find.textContaining('secret detail'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(VPayStartupScreen), findsOneWidget);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('reduced motion keeps logo static and animation disposes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const VPayStartupScreen(),
        ),
      ),
    );
    expect(find.byKey(const Key('startupLogo')), findsOneWidget);
    expect(find.byKey(const Key('startupSweep')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
