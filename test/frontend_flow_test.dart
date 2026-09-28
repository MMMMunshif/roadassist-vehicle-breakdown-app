import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

Widget testApp(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets('breakdown form blocks incomplete requests', (tester) async {
    await tester.pumpWidget(
      testApp(const BreakdownDetailsScreen(issue: 'Flat Tyre')),
    );

    await tester.tap(find.text('Confirm & Next'));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Enter a valid registration number'), findsOneWidget);
    expect(find.text('Please add at least 10 characters'), findsOneWidget);
    expect(find.text('Location Confirmation'), findsNothing);
  });

  testWidgets('valid breakdown data continues to location', (tester) async {
    await tester.pumpWidget(
      testApp(const BreakdownDetailsScreen(issue: 'Flat Tyre')),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Model / Year'),
      'Toyota Aqua 2018',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Registration Number'),
      'WP CAB 1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Detailed description'),
      'Rear tyre is punctured near the kerb.',
    );
    await tester.tap(find.text('Confirm & Next'));
    await tester.pumpAndSettle();

    expect(find.text('Location Confirmation'), findsOneWidget);
    expect(find.text('452 Galle Road, Colombo 03, Sri Lanka'), findsOneWidget);
  });

  testWidgets('driver can edit profile and sign out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp(const DriverProfileScreen()));

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Kamal Perera',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Kamal Perera'), findsOneWidget);
    expect(find.text('Profile updated successfully.'), findsOneWidget);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of RoadAssist?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(find.text('Help is closer than you think.'), findsOneWidget);
  });

  testWidgets('provider can update availability settings', (tester) async {
    await tester.pumpWidget(testApp(const ProviderProfileScreen()));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekdays · 8 AM–6 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 hours · Every day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(find.text('24 hours, 7 days a week'), findsOneWidget);
    expect(find.text('Availability settings updated.'), findsOneWidget);
  });
}
