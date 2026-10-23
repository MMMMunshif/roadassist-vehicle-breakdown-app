import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/provider_analytics.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'service selection on premium home reaches the real request form',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoadAssistTheme(Brightness.dark),
          home: const DriverHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Flat tyre'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flat tyre'));
      await tester.ensureVisible(find.text('Request Assistance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request Assistance'));
      await tester.pumpAndSettle();
      expect(find.byType(BreakdownDetailsScreen), findsOneWidget);
      final selected = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .where((chip) => chip.selected)
          .toList();
      expect(selected.length, 1);
      expect((selected.single.label as Text).data, 'Flat Tyre');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('daily earnings exclude unconfirmed cash and prior days', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 23, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RaProviderDailySummary(
            today: day,
            jobs: [
              ProviderJob('received', {
                'status': 'completed',
                'providerConfirmedPayment': true,
                'finalCost': 1200,
                'completedAt': day,
                'providerConfirmedPaymentAt': day,
                'driverRating': 5,
              }),
              ProviderJob('pending', {
                'status': 'completed',
                'providerConfirmedPayment': false,
                'finalCost': 900,
                'completedAt': day,
                'driverRating': 4,
              }),
              ProviderJob('yesterday', {
                'status': 'completed',
                'providerConfirmedPayment': true,
                'finalCost': 3000,
                'completedAt': day.subtract(const Duration(days: 1)),
              }),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rs. 1,200'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('premium request exposes both dismiss and review actions', (
    tester,
  ) async {
    var dismissed = false, viewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RaProviderRequestTile(
            driver: 'Ahamed',
            issue: 'General mechanic',
            location: 'Colombo',
            time: 'Just now',
            visitFee: 120,
            distance: '1.8 km away',
            onView: () => viewed = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    expect(dismissed, isTrue);
    await tester.tap(find.text('View request'));
    expect(viewed, isTrue);
    expect(find.text('Visit fee: Rs. 120'), findsOneWidget);
  });
}
