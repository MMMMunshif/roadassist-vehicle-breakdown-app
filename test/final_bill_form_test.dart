import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  testWidgets(
    'Final bill keeps visit fee fixed and requires a reason for parts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? bill;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  bill = await requestFinalBill(context, {'dispatchFee': 120});
                },
                child: const Text('Open bill'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open bill'));
      await tester.pumpAndSettle();
      expect(find.text('Visit fee (fixed): Rs. 120'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Inspection fee'),
        '200',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Labour / repair fee'),
        '500',
      );
      await tester.tap(find.text('Add part / additional charge'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Part or item name'),
        'Battery',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item amount'),
        '8000',
      );
      await tester.ensureVisible(find.text('Send Final Bill'));
      await tester.tap(find.text('Send Final Bill'));
      await tester.pumpAndSettle();
      expect(bill, isNull);
      expect(find.text('Explain the charge'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Why it was replaced / charged'),
        'Failed load test',
      );
      await tester.ensureVisible(find.text('Send Final Bill'));
      await tester.tap(find.text('Send Final Bill'));
      await tester.pumpAndSettle();
      expect(bill?['inspectionFee'], 200);
      expect(bill?['labourFee'], 500);
      expect(bill?['items'][0]['amount'], 8000);
      expect(bill?.containsKey('dispatchFee'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
