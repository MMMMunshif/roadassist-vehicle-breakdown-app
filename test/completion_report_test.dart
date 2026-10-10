import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/completion_report.dart';
import 'package:road_assist/src/models/service_invoice.dart';
import 'package:road_assist/src/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const report = CompletionReport(
    problem: 'The tyre valve was leaking.',
    repairs: 'Replaced valve and checked tyre pressure.',
    parts: '1 tyre valve',
    advice: 'Check tyre pressure tomorrow.',
  );
  test(
    'Completion report requires actual problem, work and parts declaration',
    () {
      expect(report.validate, returnsNormally);
      expect(
        () => const CompletionReport(
          problem: '',
          repairs: 'Work completed',
          parts: 'None',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const CompletionReport(
          problem: 'Leaking tyre valve',
          repairs: 'Changed valve',
          parts: '',
        ).validate(),
        throwsArgumentError,
      );
    },
  );
  test(
    'Repair details survive invoice and PDF export, including no parts replaced',
    () async {
      final bill = ServiceInvoice.fromRequest('job', {
        'status': 'completed',
        'finalCost': 1200,
        'estimatedCost': 1500,
        'completionReport': report.toMap(),
      });
      expect(bill.work, contains(report.problem));
      expect(bill.work, contains(report.repairs));
      expect(bill.work, contains(report.parts));
      expect(bill.work, contains(report.advice));
      expect(bill.discount, 300);
      expect(await InvoicePdfService.generate(bill), isNotEmpty);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'Repair report validates at narrow width in ${brightness.name}',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => requestCompletionReport(context, {}),
                  child: const Text('Report'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review final amount'));
        await tester.pumpAndSettle();
        expect(find.text('Enter at least 10 characters.'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  }
}
