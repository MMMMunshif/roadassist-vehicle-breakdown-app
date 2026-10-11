import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/admin_earnings_report.dart';
import 'package:road_assist/src/services/admin_earnings_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> job(
    String id,
    DateTime date,
    num amount, {
    bool paid = false,
  }) => {
    'providerId': id,
    'providerName': 'Mechanic $id',
    'status': 'completed',
    'completedAt': date,
    'finalCost': amount,
    'providerConfirmedPayment': paid,
  };
  test(
    'Report uses Sri Lanka month boundaries, provider IDs and confirmed payments',
    () {
      final report = AdminEarningsReport.aggregate(
        [
          job('a', DateTime.utc(2026, 9, 30, 18, 30), 100.25, paid: true),
          job('a', DateTime.utc(2026, 10, 1), 200),
          job('b', DateTime.utc(2026, 10, 1), 400),
          job('a', DateTime.utc(2026, 9, 30, 18, 29), 900),
          {...job('a', DateTime.utc(2026, 10, 1), 900), 'status': 'cancelled'},
          {
            ...job('a', DateTime.utc(2026, 10, 1), 100),
            'finalCost': null,
            'estimatedCost': 999,
          },
          job('a', DateTime.utc(2026, 10, 1), -1),
          job('', DateTime.utc(2026, 10, 1), 100),
        ],
        generatedAt: DateTime.utc(2026, 10, 9, 6),
        month: DateTime(2026, 10),
      );
      expect(report.billedCents, 70025);
      expect(report.confirmedCents, 10025);
      expect(report.jobs, 3);
      expect(report.details.length, 3);
      expect(report.forProvider('a').details.length, 2);
      expect(report.excluded, 3);
      expect(report.forProvider('a').billedCents, 30025);
      expect(report.forProvider('b').billedCents, 40000);
      expect(report.generatedLabel, '2026-10-09 11:30:00 UTC+05:30');
    },
  );
  test(
    'All-month report keeps monthly rows separate and accepts zero-cost jobs',
    () {
      final report = AdminEarningsReport.aggregate([
        job('a', DateTime.utc(2026, 9, 1), 100),
        job('a', DateTime.utc(2026, 10, 1), 0),
      ], generatedAt: DateTime.utc(2026, 10, 9));
      expect(report.rows.length, 2);
      expect(report.rows.first.month, '2026-10');
      expect(report.jobs, 2);
      expect(report.billedCents, 10000);
    },
  );
  test(
    'Branded report PDF supports multiple pages and an empty period',
    () async {
      final rows = List.generate(150, (i) {
        final row = ProviderMonthlyEarnings(
          'provider-$i',
          'Professional Mechanic $i',
          '2026-10',
        );
        row.email = 'provider$i@example.com';
        row.phone = '+94771234567';
        row.jobs = 2;
        row.billedCents = 150000;
        row.confirmedCents = 100000;
        return row;
      });
      final report = AdminEarningsReport(
        rows: rows,
        generatedAt: DateTime.utc(2026, 10, 9, 6),
        period: 'SAMPLE - 2026-10',
        details: [
          for (var i = 0; i < 150; i++)
            for (final paid in [true, false])
              {
                ...job(
                  'provider-$i',
                  DateTime.utc(2026, 10, 9),
                  paid ? 1000 : 500,
                  paid: paid,
                ),
                'driverName': 'Sample Driver',
                'registration': 'SAMPLE VEHICLE',
                'issue': 'Flat Tyre',
                'amountCents': paid ? 100000 : 50000,
              },
        ],
      );
      final bytes = await AdminEarningsPdfService.generate(report);
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(bytes.length, lessThan(3000000));
      await Directory('build').create(recursive: true);
      await File('build/admin-earnings-sample.pdf').writeAsBytes(bytes);
      final empty = await AdminEarningsPdfService.generate(
        AdminEarningsReport(
          rows: [],
          generatedAt: DateTime.utc(2026, 10, 9),
          period: 'SAMPLE - empty',
        ),
      );
      expect(latin1.decode(empty.take(5).toList()), '%PDF-');
    },
  );
}
