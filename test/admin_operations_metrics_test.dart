import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  testWidgets(
    'Four metrics use correct event dates, weighted response time and final bills',
    (tester) async {
      Timestamp date(int day, int minutes) =>
          Timestamp.fromDate(DateTime(2026, 10, day, 12, minutes));
      final records = <Map<String, dynamic>>[
        {
          'createdAt': date(9, 0),
          'acceptedAt': date(9, 10),
          'completedAt': date(9, 30),
          'status': 'completed',
          'finalCost': 1000,
        },
        {
          'createdAt': date(9, 0),
          'acceptedAt': date(9, 30),
          'status': 'accepted',
        },
        {
          'createdAt': date(1, 0),
          'acceptedAt': date(1, 0),
          'completedAt': date(9, 45),
          'status': 'completed',
          'finalCost': 500,
        },
        {'createdAt': date(9, 0), 'status': 'cancelled', 'finalCost': 9000},
        {
          'createdAt': date(9, 0),
          'completedAt': date(9, 40),
          'status': 'completed',
          'estimatedCost': 2000,
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminOperationsChart(
                records: records,
                today: DateTime(2026, 10, 9),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Requests: 4'), findsOneWidget);
      expect(find.text('Completed jobs: 3'), findsOneWidget);
      expect(find.text('Response time: 20.0 min'), findsOneWidget);
      expect(find.text('Service value: Rs. 1500.00'), findsOneWidget);
      await tester.tap(find.text('30 Days'));
      await tester.pump();
      expect(find.text('Requests: 5'), findsOneWidget);
      expect(find.text('Response time: 13.3 min'), findsOneWidget);
      for (final name in ['Completed jobs', 'Response time', 'Service value']) {
        await tester.tap(find.widgetWithText(FilterChip, name));
        await tester.pump();
      }
      expect(find.textContaining('Actual scale: Requests'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Requests'));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Requests'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
