class ProviderMonthlyEarnings {
  ProviderMonthlyEarnings(this.providerId, this.name, this.month);
  final String providerId, month;
  String name;
  String email = '', phone = '';
  int jobs = 0, billedCents = 0, confirmedCents = 0;
}

class AdminEarningsReport {
  AdminEarningsReport({
    required this.rows,
    required this.generatedAt,
    required this.period,
    this.excluded = 0,
    this.details = const [],
  });
  final List<ProviderMonthlyEarnings> rows;
  final DateTime generatedAt;
  final String period;
  final int excluded;
  final List<Map<String, dynamic>> details;
  int get billedCents => rows.fold(0, (sum, row) => sum + row.billedCents);
  int get confirmedCents =>
      rows.fold(0, (sum, row) => sum + row.confirmedCents);
  int get jobs => rows.fold(0, (sum, row) => sum + row.jobs);
  static String money(int cents) => 'Rs. ${(cents / 100).toStringAsFixed(2)}';
  static DateTime sriLanka(DateTime time) =>
      time.toUtc().add(const Duration(minutes: 330));
  static String monthLabel(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}';
  String get generatedLabel =>
      '${sriLanka(generatedAt).toIso8601String().substring(0, 19).replaceFirst('T', ' ')} UTC+05:30';
  AdminEarningsReport forProvider(String id) => AdminEarningsReport(
    rows: rows.where((row) => row.providerId == id).toList(),
    generatedAt: generatedAt,
    period: period,
    excluded: excluded,
    details: details.where((job) => job['providerId'] == id).toList(),
  );
  static AdminEarningsReport aggregate(
    List<Map<String, dynamic>> records, {
    required DateTime generatedAt,
    DateTime? month,
  }) {
    final grouped = <String, ProviderMonthlyEarnings>{};
    var excluded = 0;
    final details = <Map<String, dynamic>>[];
    for (final record in records) {
      if (record['status'] != 'completed') continue;
      final raw = record['completedAt'];
      if (raw is! DateTime) {
        excluded++;
        continue;
      }
      final date = sriLanka(raw);
      if (month != null &&
          (date.year != month.year || date.month != month.month))
        continue;
      final uid = record['providerId'], amount = record['finalCost'];
      if (uid is! String ||
          uid.trim().isEmpty ||
          amount is! num ||
          !amount.isFinite ||
          amount < 0) {
        excluded++;
        continue;
      }
      final label = monthLabel(date), key = '$uid/$label';
      final row = grouped.putIfAbsent(
        key,
        () => ProviderMonthlyEarnings(
          uid,
          record['providerName']?.toString().trim().isNotEmpty == true
              ? record['providerName'].toString()
              : 'Provider',
          label,
        ),
      );
      final cents = (amount * 100).round();
      if (row.phone.isEmpty)
        row.phone = record['providerPhone']?.toString() ?? '';
      if (row.email.isEmpty)
        row.email = record['providerEmail']?.toString() ?? '';
      details.add({...record, 'amountCents': cents});
      row.jobs++;
      row.billedCents += cents;
      if (record['providerConfirmedPayment'] == true)
        row.confirmedCents += cents;
    }
    final rows = grouped.values.toList()
      ..sort((a, b) {
        final month = b.month.compareTo(a.month);
        return month != 0 ? month : a.providerId.compareTo(b.providerId);
      });
    return AdminEarningsReport(
      rows: rows,
      generatedAt: generatedAt,
      period: month == null ? 'All recorded months' : monthLabel(month),
      excluded: excluded,
      details: details,
    );
  }
}
