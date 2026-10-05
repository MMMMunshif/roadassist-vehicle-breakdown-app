import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/repair_revision.dart';
import 'package:road_assist/src/screens.dart';

String? validate(
  int amount, {
  String reason = 'Damaged part discovered during inspection',
  List<String> photos = const [],
}) => validateRepairRevision(
  previousTotal: 1800,
  total: amount,
  reason: reason,
  photos: photos,
);
void main() {
  test('price increase needs photo evidence and an explanation', () {
    expect(validate(2000), contains('photo'));
    expect(
      validate(2000, reason: 'extra', photos: ['photo']),
      contains('reason'),
    );
    expect(validate(2000, photos: ['photo']), isNull);
  });
  test('discount still requires a reason but no photo', () {
    expect(validate(1700), isNull);
    expect(validate(1700, reason: ''), isNotNull);
  });
  test('invalid totals and oversized evidence cannot be submitted', () {
    expect(validate(-1), isNotNull);
    expect(validate(10000001), isNotNull);
    expect(validate(2000, photos: ['a', 'b', 'c']), isNotNull);
    expect(validate(2000, photos: ['x' * 210001]), isNotNull);
  });
  testWidgets(
    'price change form blocks an increase until reason and photo are supplied',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  requestProviderQuote(context, {
                    'workflowVersion': 2,
                    'repairRevision': true,
                    'estimatedCost': 1800,
                    'serviceFee': 1800,
                    'dispatchFee': 0,
                    'extraFee': 0,
                  });
                },
                child: const Text('Change price'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Change price'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Included work, parts and exclusions'),
        'Replace damaged valve, labour included',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for price / work change'),
        'Damaged valve discovered during inspection',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Service / labour charge'),
        '2000',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send Offer'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Attach a photo'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Service / labour charge'),
        '1800',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send Offer'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('invoice values use readable dark-theme surface text', (
    tester,
  ) async {
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: SummaryRow('Travel', 'Rs. 300')),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Rs. 300')).style!.color,
      theme.colorScheme.onSurface,
    );
  });
}
