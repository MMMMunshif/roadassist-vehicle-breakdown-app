import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Pattern preserves scrolling and controls in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: RaScaffold(
            body: ListView(
              children: [
                const SizedBox(height: 1200),
                TextButton(
                  onPressed: () {},
                  child: const Text('Bottom action'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Bottom action'), 400);
      await tester.tap(find.text('Bottom action'));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Unsaved changes can stay or discard without a dialog loop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RaScaffold(
                    preventLeave: true,
                    appBar: AppBar(title: const Text('Edit')),
                    body: const Text('Editor'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this page?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Leave this page?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
