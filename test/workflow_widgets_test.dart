import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final brightness in Brightness.values) {
    for (final provider in [false, true]) {
      testWidgets(
        'job start card fits small screen with large text $brightness/$provider',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildRoadAssistTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: JobStartCodePanel(
                    requestId: 'sample',
                    isProvider: provider,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Confirm job start'), findsOneWidget);
          if (provider) {
            await tester.enterText(find.byType(TextField), 'abc12');
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              '12',
            );
            await tester.ensureVisible(find.text('Verify and start job'));
            await tester.tap(find.text('Verify and start job'));
            await tester.pumpAndSettle();
            expect(
              find.text('Enter the six-digit code shown on the driver phone.'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets('stale location never presents a current distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveLocationStatus(
            updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
            hasPosition: true,
            distanceKm: 3,
          ),
        ),
      ),
    );
    expect(find.textContaining('may be outdated'), findsOneWidget);
    expect(find.textContaining('3.0 km'), findsNothing);
  });
}
