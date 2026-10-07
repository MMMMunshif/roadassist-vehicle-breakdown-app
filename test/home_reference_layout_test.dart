import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final brightness in Brightness.values) {
    for (final width in [280.0, 320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'reference home fits $width at $scale in ${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: buildRoadAssistTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(body: DriverHomeScreen()),
              ),
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Request Assistance'),
              200,
            );
            await tester.pumpAndSettle();
            expect(find.text('Request Assistance'), findsOneWidget);

            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.text('Quick Help'), 200);
            await tester.pumpAndSettle();
            expect(find.text('Won’t Start'), findsOneWidget);
            expect(find.text('Flat Tyre'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(
              find.text('Emergency'),
              200,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
