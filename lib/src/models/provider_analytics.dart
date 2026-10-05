import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderJob {
  ProviderJob(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  DateTime? date(String key) {
    final value = data[key];
    return value is Timestamp
        ? value.toDate().toLocal()
        : value is DateTime
        ? value.toLocal()
        : null;
  }

  String get status => data['status'] as String? ?? '';
  String get service => data['issue'] as String? ?? 'Unspecified';
  bool get completed => status == 'completed';
  bool get paid => completed && data['providerConfirmedPayment'] == true;
  int get amount {
    final value = data['finalCost'] ?? data['estimatedCost'];
    return value is num && value.isFinite && value >= 0 ? value.round() : 0;
  }

  DateTime? get completionDate => date('completedAt') ?? date('createdAt');
  DateTime? get revenueDate => date('paymentConfirmedAt') ?? completionDate;
  DateTime? get activityDate => completed
      ? completionDate
      : status == 'cancelled'
      ? date('cancelledAt') ?? date('createdAt')
      : date('acceptedAt') ?? date('createdAt');
  double? get rating {
    final value = data['driverRating'];
    return value is num && value >= 1 && value <= 5 ? value.toDouble() : null;
  }
}

class ProviderAnalytics {
  ProviderAnalytics(List<ProviderJob> jobs, DateTime first, DateTime last)
    : start = DateTime(first.year, first.month, first.day),
      end = DateTime(last.year, last.month, last.day + 1),
      all = List.unmodifiable(jobs);
  final DateTime start;
  final DateTime end;
  final List<ProviderJob> all;
  bool includes(DateTime? date) =>
      date != null && !date.isBefore(start) && date.isBefore(end);
  List<ProviderJob> get paid =>
      all.where((j) => j.paid && includes(j.revenueDate)).toList();
  List<ProviderJob> get completed =>
      all.where((j) => j.completed && includes(j.completionDate)).toList();
  List<ProviderJob> get pending => all
      .where((j) => j.completed && !j.paid && includes(j.completionDate))
      .toList();
  List<ProviderJob> get activity =>
      all.where((j) => includes(j.activityDate)).toList();
  int get revenue => paid.fold(0, (sum, j) => sum + j.amount);
  int get pendingTotal => pending.fold(0, (sum, j) => sum + j.amount);
  int get allPendingTotal => all
      .where((j) => j.completed && !j.paid)
      .fold(0, (sum, j) => sum + j.amount);
  int get cancelled => activity.where((j) => j.status == 'cancelled').length;
  double? get cancellationRate {
    final terminal = completed.length + cancelled;
    return terminal == 0 ? null : cancelled * 100 / terminal;
  }

  double? get averageRating {
    final values = completed.map((j) => j.rating).whereType<double>().toList();
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  int get ratingCount => completed.where((j) => j.rating != null).length;
  int get previousRevenue {
    final length = end.difference(start).inDays;
    final previousStart = DateTime(start.year, start.month, start.day - length);
    return all
        .where(
          (j) =>
              j.paid &&
              j.revenueDate != null &&
              !j.revenueDate!.isBefore(previousStart) &&
              j.revenueDate!.isBefore(start),
        )
        .fold(0, (sum, j) => sum + j.amount);
  }

  Map<String, int> get byService {
    final result = <String, int>{};
    for (final job in paid) {
      result.update(
        job.service,
        (v) => v + job.amount,
        ifAbsent: () => job.amount,
      );
    }
    return result;
  }

  Map<DateTime, int> get dailyRevenue {
    final result = <DateTime, int>{};
    for (
      var day = start;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      result[day] = 0;
    }
    for (final job in paid) {
      final date = job.revenueDate!;
      final day = DateTime(date.year, date.month, date.day);
      result[day] = result[day]! + job.amount;
    }
    return result;
  }

  String get csv {
    String cell(Object? value) {
      var text = value?.toString() ?? '';
      // Spreadsheet applications can execute formulas in exported user text.
      if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final selected =
        all
            .where(
              (j) =>
                  includes(j.activityDate) ||
                  (j.paid && includes(j.revenueDate)),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final rows = <List<Object?>>[
      [
        'Job ID',
        'Service',
        'Status',
        'Completed date',
        'Payment confirmed date',
        'Invoice amount LKR',
        'Payment status',
        'Counts in selected revenue',
      ],
      for (final job in selected)
        [
          job.id,
          job.service,
          job.status,
          job.completed ? job.completionDate?.toIso8601String() : '',
          job.paid ? job.revenueDate?.toIso8601String() : '',
          job.completed ? job.amount : '',
          job.paid
              ? 'Provider confirmed'
              : job.completed
              ? job.data['driverReportedPayment'] == true
                    ? 'Driver reported; unconfirmed'
                    : 'Not recorded'
              : 'Not completed',
          job.paid && includes(job.revenueDate) ? 'Yes' : 'No',
        ],
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\r\n');
  }
}
