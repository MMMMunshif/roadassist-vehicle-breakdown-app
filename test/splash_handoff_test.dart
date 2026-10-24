import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/widgets/splash_rescue_scene.dart';

void main() {
  testWidgets(
    'handshake scene has no loading indicator and shares heroes with Welcome',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoadAssistTheme(Brightness.dark),
          home: SplashScreen(
            destinationLoader: () async => const WelcomeScreen(),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(
        tester
            .widget<SplashRescueScene>(find.byType(SplashRescueScene))
            .progress,
        closeTo(2800 / 4200, .01),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(Hero), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      await tester.ensureVisible(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'slow destination resolution stays static and does not invent progress',
    (tester) async {
      final ready = Completer<Widget>();
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(destinationLoader: () => ready.future)),
      );
      await tester.pump(const Duration(milliseconds: 4400));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(
        tester
            .widget<SplashRescueScene>(find.byType(SplashRescueScene))
            .progress,
        1,
      );
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
      await tester.pumpAndSettle();
      expect(find.text('Verification destination'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
