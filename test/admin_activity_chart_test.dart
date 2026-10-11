import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  testWidgets(
    'Correction dialog requires selection and returns only selected documents',
    (tester) async {
      ProviderCorrectionDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<ProviderCorrectionDraft>(
                    context: context,
                    builder: (_) => const ProviderCorrectionDialog(
                      documentKeys: ['selfie', 'nicBack'],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Please replace the blurred face photo.',
      );
      await tester.tap(find.text('Send correction request'));
      await tester.pumpAndSettle();
      expect(find.text('Select at least one document.'), findsOneWidget);
      await tester.tap(find.text('Provider selfie'));
      await tester.pump();
      await tester.tap(find.text('Send correction request'));
      await tester.pumpAndSettle();
      expect(result?.documents, ['selfie']);
      expect(result?.reason, 'Please replace the blurred face photo.');
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Activity chart fits $brightness at scale $scale', (
        tester,
      ) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AdminOperationsChart(
                      records: const [],
                      today: DateTime(2026, 10, 9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('View daily figures'));
        await tester.tap(find.text('View daily figures'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '9/10: Requests 0, Completed jobs 0, Response time No data, Service value Rs. 0.00',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
