import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final brightness in Brightness.values) {
    testWidgets('active stage fits narrow screen in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget screen(
        int stage,
        String title, {
        bool cancelled = false,
        bool reduce = false,
      }) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 844),
            textScaler: const TextScaler.linear(1.5),
            disableAnimations: reduce,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ActiveAssistanceStatusCard(
                status: stage,
                title: title,
                description:
                    'Confirm arrival only after physically meeting your provider.',
                cancelled: cancelled,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(1, 'Your provider is on the way'));
      await tester.pumpAndSettle();
      expect(find.text('En route'), findsOneWidget);
      expect(find.byType(StatusTimeline), findsOneWidget);
      await tester.pumpWidget(screen(2, 'Your provider has arrived'));
      await tester.pumpAndSettle();
      expect(find.text('Your provider has arrived'), findsOneWidget);
      expect(find.text('Your provider is on the way'), findsNothing);
      expect(find.text('Payment received'), findsNothing);
      await tester.pumpWidget(
        screen(2, 'Assistance cancelled', cancelled: true, reduce: true),
      );
      await tester.pump();
      expect(find.text('REQUEST CLOSED'), findsOneWidget);
      expect(find.byType(StatusTimeline), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
