import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/provider_analytics.dart';

void main() {
  ProviderJob job(
    String id, {
    String status = 'completed',
    bool paid = true,
    int amount = 1000,
    DateTime? completed,
    DateTime? payment,
    String issue = 'Flat Tyre',
    bool reported = false,
  }) => ProviderJob(id, {
    'status': status,
    'providerConfirmedPayment': paid,
    'driverReportedPayment': reported,
    'finalCost': amount,
    'completedAt': completed ?? DateTime(2026, 10, 5),
    'paymentConfirmedAt': payment ?? DateTime(2026, 10, 5),
    'issue': issue,
  });
  test('only completed provider-confirmed payments count as revenue', () {
    final a = ProviderAnalytics(
      [
        job('paid'),
        job('reported', paid: false, reported: true),
        job('unpaid', paid: false),
        job('cancelled', status: 'cancelled'),
        job('active', status: 'arrived'),
      ],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    );
    expect(a.revenue, 1000);
    expect(a.pendingTotal, 2000);
    expect(a.completed.length, 3);
    expect(a.dailyRevenue.values.reduce((a, b) => a + b), a.revenue);
  });
  test(
    'revenue uses payment date and inclusive dates; unpaid uses completion date',
    () {
      final a = ProviderAnalytics(
        [
          job(
            'late',
            completed: DateTime(2026, 9, 20),
            payment: DateTime(2026, 10, 5, 23, 59),
          ),
          job('tomorrow', payment: DateTime(2026, 10, 6)),
          job('old', paid: false, completed: DateTime(2026, 9, 20)),
        ],
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 5),
      );
      expect(a.revenue, 1000);
      expect(a.completed.length, 1);
      expect(a.pendingTotal, 0);
      expect(a.allPendingTotal, 1000);
    },
  );
  test('service grouping never duplicates multiple issue revenue', () {
    final multi = job('multi');
    multi.data['issues'] = ['Flat Tyre', 'Battery Jumpstart'];
    final a = ProviderAnalytics(
      [multi, job('battery', issue: 'Battery Jumpstart', amount: 2000)],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    );
    expect(a.byService, {'Flat Tyre': 1000, 'Battery Jumpstart': 2000});
  });
  test('empty periods and missing ratings have no invented metrics', () {
    final a = ProviderAnalytics(
      [],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    );
    expect(a.revenue, 0);
    expect(a.averageRating, isNull);
    expect(a.cancellationRate, isNull);
    expect(a.dailyRevenue.length, 5);
  });
  test('previous period uses the same number of calendar days', () {
    final a = ProviderAnalytics(
      [
        job('previous', amount: 2500, payment: DateTime(2026, 9, 30)),
        job('current'),
      ],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    );
    expect(a.previousRevenue, 2500);
    expect(a.revenue, 1000);
  });
  test('CSV preserves quotes and guards spreadsheet formula injection', () {
    final a = ProviderAnalytics(
      [job('=HYPERLINK("test")', issue: 'Flat, "Tyre"')],
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    );
    expect(a.csv, contains('"\'=HYPERLINK(""test"")"'));
    expect(a.csv, contains('"Flat, ""Tyre"""'));
    expect(a.csv, contains('Provider confirmed'));
  });
}
