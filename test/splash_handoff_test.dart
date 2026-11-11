import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/widgets/splash_rescue_scene.dart';

void main() {
  testWidgets('ready destination waits 2.5 seconds before the 650ms handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          destinationLoader: () async =>
              const Scaffold(body: Text('Next screen')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Next screen'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
  testWidgets('static brand hands off with a fade after the minimum display', (
    tester,
  ) async {
    final ready = Completer<Widget>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoadAssistTheme(Brightness.dark),
        home: SplashScreen(destinationLoader: () => ready.future),
      ),
    );
    expect(find.text('Roadside help. Within reach.'), findsOneWidget);
    expect(find.byType(SplashRescueScene), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.transientCallbackCount, 0);
    ready.complete(const WelcomeScreen());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'slow destination resolution stays static and does not invent progress',
    (tester) async {
      final ready = Completer<Widget>();
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(destinationLoader: () => ready.future)),
      );
      await tester.pump(const Duration(milliseconds: 4400));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(SplashRescueScene), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      ready.complete(const Scaffold(body: Text('Protected destination')));
      await tester.pumpAndSettle();
      expect(find.text('Protected destination'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    },
  );
  testWidgets('disposing during pending startup cancels motion safely', (
    tester,
  ) async {
    final ready = Completer<Widget>();
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(destinationLoader: () => ready.future)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    ready.complete(const WelcomeScreen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reduced motion skips cinematic wait and keeps the selected destination',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SplashScreen(
            destinationLoader: () async =>
                const Scaffold(body: Text('Verification destination')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(find.text('Verification destination'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
