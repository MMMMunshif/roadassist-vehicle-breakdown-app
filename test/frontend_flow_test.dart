import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/screens.dart';

Widget testApp(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets(
    'driver photo upload is shown for signup and hidden for sign in',
    (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(isProvider: false)));
      expect(find.text('Driver photo'), findsNothing);
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Driver photo'), findsOneWidget);
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();
      expect(find.text('Driver photo'), findsNothing);
      expect(find.byTooltip('Add profile photo'), findsNothing);
    },
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('breakdown form blocks incomplete requests', (tester) async {
    await tester.pumpWidget(
      testApp(const BreakdownDetailsScreen(issues: ['Flat Tyre'])),
    );

    await tester.tap(find.text('Continue to Location'));
    await tester.pump();

    expect(find.text('Enter the vehicle model and year'), findsOneWidget);
    expect(
      find.text('Use a format such as WP CAB-1234 or CAA-1234'),
      findsOneWidget,
    );
    expect(find.text('Confirm Location'), findsNothing);
  });

  testWidgets('other vehicle type requires a custom value', (tester) async {
    await tester.pumpWidget(
      testApp(const BreakdownDetailsScreen(issues: ['General Mechanic'])),
    );

    await tester.tap(find.text('Sedan / Hatchback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Other vehicle type'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue to Location'));
    await tester.pump();
    expect(find.text('Enter your vehicle type'), findsOneWidget);
  });

  testWidgets('valid breakdown data continues to location', (tester) async {
    await tester.pumpWidget(
      testApp(const BreakdownDetailsScreen(issues: ['Flat Tyre'])),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Make, model & year'),
      'Toyota Aqua 2018',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Registration number'),
      'WP CAB 1234',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'What happened?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened?'),
      'Rear tyre is punctured near the kerb.',
    );
    await tester.tap(find.text('Continue to Location'));
    // The destination contains a live map/loading animation; do not wait for
    // every animation to stop to verify that navigation completed.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Confirm Location'), findsOneWidget);
    expect(find.byType(LocationScreen), findsOneWidget);
  });

  test('vehicle registration is normalised before validation', () {
    expect(normalizeVehicleRegistration(' wp cab - 1234 '), 'WP CAB-1234');
    expect(validateVehicleRegistration('WP CAB-1234'), isNull);
    expect(validateVehicleRegistration('123'), isNotNull);
  });

  test('vehicle model requires a realistic year', () {
    expect(validateVehicleModelYear('Toyota Aqua 2018'), isNull);
    expect(validateVehicleModelYear('Toyota Aqua'), isNotNull);
    expect(validateVehicleModelYear('Toyota Aqua 1900'), isNotNull);
  });

  test('custom vehicle type must contain a meaningful name', () {
    expect(validateCustomVehicleType('Three Wheeler'), isNull);
    expect(validateCustomVehicleType(''), 'Enter your vehicle type');
    expect(validateCustomVehicleType('12'), 'Enter a valid vehicle type');
  });

  test('breakdown description is optional', () {
    expect(validateBreakdownDescription(''), isNull);
    expect(
      validateBreakdownDescription('Rear tyre has a deep puncture'),
      isNull,
    );
    expect(validateBreakdownDescription('Tyre flat'), isNull);
  });

  testWidgets('signed-out drivers cannot edit a profile', (tester) async {
    await tester.pumpWidget(testApp(const DriverProfileScreen()));
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsNothing);
  });

  testWidgets('provider can update availability settings', (tester) async {
    await tester.pumpWidget(testApp(const ProviderProfileScreen()));

    await tester.tap(find.byTooltip('Availability settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekdays · 8 AM–6 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 hours · Every day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('24 hours, 7 days a week'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('24 hours, 7 days a week'), findsOneWidget);
    expect(find.text('Availability settings updated.'), findsOneWidget);
  });
}
