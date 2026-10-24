import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/widgets/auth_journey_scene.dart';

void main() {
  for (final provider in [false, true]) {
    testWidgets(
      'Welcome role choice opens matching login and vehicle: $provider',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(Brightness.dark),
            home: const WelcomeScreen(),
          ),
        );
        await tester.ensureVisible(find.text('Get Started'));
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        final choice = find.text(
          provider ? 'Continue as Provider' : 'Continue as Driver',
        );
        await tester.scrollUntilVisible(choice, 250, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          tester.widget<LoginScreen>(find.byType(LoginScreen)).isProvider,
          provider,
        );
        expect(
          tester
              .widget<AuthJourneyScene>(find.byType(AuthJourneyScene))
              .provider,
          provider,
        );
        expect(find.text('Good to see you.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('password focus and eye control the privacy state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoadAssistTheme(Brightness.light),
        home: const LoginScreen(isProvider: false),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('auth_password_field'));
    final scene = tester.widget<AuthJourneyScene>(
      find.byType(AuthJourneyScene),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(scene.controller.phase, AuthJourneyPhase.password);
    expect(scene.controller.privacy, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(scene.controller.privacy, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets(
      'car departs only on explicit success, reduced motion $reduced',
      (tester) async {
        final controller = AuthJourneyController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(body: AuthJourneyScene(controller: controller)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.update(phase: AuthJourneyPhase.authenticating);
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.phase, AuthJourneyPhase.authenticating);
        controller.update(phase: AuthJourneyPhase.idle);
        await tester.pumpAndSettle();
        expect(controller.phase, AuthJourneyPhase.idle);
        var complete = false;
        final future = controller.complete().then((_) {
          complete = true;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await future;
        expect(complete, isTrue);
        expect(controller.phase, AuthJourneyPhase.success);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('password reset retains the previously selected provider role', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: const LoginScreen(isProvider: true)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('auth_forgot_password')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_forgot_password')));
    await tester.pumpAndSettle();
    expect(find.text('Reset provider password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'common reset asks role and provider signup uses provider scene',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('auth_forgot_password')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_forgot_password')));
      await tester.pumpAndSettle();
      expect(find.text('Which password do you want to reset?'), findsOneWidget);
      await tester.tap(find.text('I provide help'));
      await tester.pumpAndSettle();
      expect(find.text('Reset provider password'), findsOneWidget);
      Navigator.of(tester.element(find.text('Reset provider password'))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I provide help'));
      await tester.pumpAndSettle();
      final scene = tester.widget<AuthJourneyScene>(
        find.byType(AuthJourneyScene),
      );
      expect(scene.provider, isTrue);
      expect(scene.registration, isTrue);
      expect(find.text('Driver photo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
