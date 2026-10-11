import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/service_invoice.dart';
import 'package:road_assist/src/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> record() => {
    'status': 'completed',
    'estimatedCost': 5000,
    'finalCost': 4500,
    'serviceFee': 4000,
    'dispatchFee': 1000,
    'driverName': 'A customer with a long name',
    'providerName': 'Professional roadside assistance provider',
    'issues': ['Flat Tyre'],
    'completedAt': DateTime(2026, 10, 9),
    'warrantyDays': 7,
  };
  test('Recorded charges reconcile with subtotal and discount', () {
    final bill = ServiceInvoice.fromRequest('job123', record());
    expect(
      bill.charges.fold<int>(0, (sum, c) => sum + c.amount) - bill.discount,
      bill.total,
    );
    expect(bill.discount, 500);
    expect(bill.paid, false);
    expect(bill.number, 'RA-job123');
  });
  test(
    'Driver report alone never marks bill paid; repair warranty overrides root',
    () {
      final bill = ServiceInvoice.fromRequest(
        'id',
        {...record(), 'driverReportedPayment': true},
        approvedOffer: {'warrantyDays': 30, 'warrantyTerms': 'Repair only'},
      );
      expect(bill.paid, false);
      expect(bill.warranty, contains('30 days'));
      expect(
        ServiceInvoice.fromRequest('id', {
          ...record(),
          'providerConfirmedPayment': true,
        }).paid,
        true,
      );
    },
  );
  test(
    'Legacy or mismatched breakdown uses recorded total without invented charges',
    () {
      final bill = ServiceInvoice.fromRequest('id', {
        'status': 'completed',
        'finalCost': 6000,
        'serviceFee': 100,
      });
      expect(bill.charges.single.amount, 6000);
      expect(bill.charges.single.label, 'Recorded service charge');
      expect(
        () => ServiceInvoice.fromRequest('id', {'status': 'accepted'}),
        throwsStateError,
      );
      expect(
        () => ServiceInvoice.fromRequest('id', {'status': 'completed'}),
        throwsStateError,
      );
    },
  );
  test('Branded PDF renders bundled assets and recorded data', () async {
    final bytes = await InvoicePdfService.generate(
      ServiceInvoice.fromRequest('job123', record()),
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
  });
  test('Invalid final amount cannot fall back to an older estimate', () {
    expect(
      () => ServiceInvoice.fromRequest('id', {...record(), 'finalCost': -1}),
      throwsStateError,
    );
  });
  test('Long service notes still generate a PDF', () async {
    final bill = ServiceInvoice.fromRequest('long-job', {
      ...record(),
      'serviceNotes': List.filled(
        35,
        'Completed tyre repair and checked the approved roadside work.',
      ).join(' '),
    });
    expect(await InvoicePdfService.generate(bill), isNotEmpty);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Invoice at 320px scale $scale ${brightness.name}', (
        tester,
      ) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: InvoiceBillView(
                  invoice: ServiceInvoice.fromRequest('job123', record()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
