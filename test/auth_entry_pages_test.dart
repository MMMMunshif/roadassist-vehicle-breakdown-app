import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  testWidgets(
    'driver registration starts in signup and can return to sign in',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegistrationScreen(isProvider: false)),
      );
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('Driver photo'), findsOneWidget);
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();
      expect(find.text('FULL NAME'), findsNothing);
      expect(find.text('Driver photo'), findsNothing);
    },
  );
  testWidgets('provider registration preserves verification instructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegistrationScreen(isProvider: true)),
    );
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('Create Provider Account'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Provider accounts require verification'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Provider accounts require verification'),
      findsOneWidget,
    );
    expect(find.text('Driver photo'), findsNothing);
  });
}
