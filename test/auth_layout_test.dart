import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 430.0]) {
      final pages = <String, Widget>{
        'welcome': const WelcomeScreen(),
        'login': const LoginScreen(isProvider: false),
        'driver signup': const RegistrationScreen(isProvider: false),
        'provider signup': const RegistrationScreen(isProvider: true),
      };
      for (final entry in pages.entries) {
        testWidgets(
          '${entry.key} fits $width with large text in ${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: buildRoadAssistTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: entry.value,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -650),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'splash leaves for welcome without an available Firebase session',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoadAssistTheme(Brightness.light),
          home: const SplashScreen(),
        ),
      );
      expect(find.text('Roadside support,\nwhen it matters.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
