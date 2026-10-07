import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  testWidgets(
    'warranty offer requires coverage before sending and carries agreed terms',
    (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await requestProviderQuote(context, {
                    'workflowVersion': 2,
                  });
                },
                child: const Text('Quote'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Service / labour charge'),
        '1500',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Included work, parts and exclusions'),
        'Puncture repair',
      );
      await tester.ensureVisible(find.text('No service warranty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No service warranty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 days').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send Offer'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Warranty coverage'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Warranty coverage'),
        'Same puncture only; new damage excluded.',
      );
      await tester.pump();
      await tester.tap(find.text('Send Offer'));
      await tester.pumpAndSettle();
      expect(result?['warrantyDays'], 30);
      expect(
        result?['warrantyTerms'],
        'Same puncture only; new damage excluded.',
      );
      expect(result?['serviceFee'], 1500);
    },
  );
}
