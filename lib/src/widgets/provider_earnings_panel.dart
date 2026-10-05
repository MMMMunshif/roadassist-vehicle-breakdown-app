part of '../screens.dart';

String _businessDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _businessMoney(num value) =>
    'Rs. ${value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

class _ProviderEarningsPanel extends StatefulWidget {
  const _ProviderEarningsPanel();
  @override
  State<_ProviderEarningsPanel> createState() => _ProviderEarningsPanelState();
}

class _ProviderEarningsPanelState extends State<_ProviderEarningsPanel> {
  late final jobs = RequestService().watchProviderRequests();
  int days = 30;
  DateTimeRange? custom;
  Future<void> chooseDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: custom,
      helpText: 'Select report dates (up to 366 days)',
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays >= 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select no more than 366 days.')),
      );
      return;
    }
    setState(() => custom = range);
  }

  void showJobs(String title, List<ProviderJob> selected) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: RaText.title),
              ),
              Expanded(
                child: selected.isEmpty
                    ? const Center(child: Text('No jobs in this group.'))
                    : ListView(
                        children: selected
                            .map(
                              (job) => ListTile(
                                title: Text(
                                  '${job.data['driverName'] ?? 'Driver'}  -  ${_businessMoney(job.amount)}',
                                ),
                                subtitle: Text('${job.service}\n${job.id}'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(context);
                                  push(
                                    this.context,
                                    job.completed
                                        ? InvoiceScreen(requestId: job.id)
                                        : ProviderRequestDetailsScreen(
                                            requestId: job.id,
                                            data: job.data,
                                          ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget metric(
    String title,
    String value,
    String subtitle,
    VoidCallback? action,
  ) => SizedBox(
    width: 162,
    child: Card(
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RaText.caption),
              const SizedBox(height: 6),
              Text(value, style: RaText.numeric),
              const SizedBox(height: 4),
              Text(subtitle, style: RaText.caption),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: jobs,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Business overview could not load. Check your connection and reopen the dashboard.',
            ),
          ),
        );
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final now = DateTime.now();
      final all = snapshot.data!.docs
          .map((d) => ProviderJob(d.id, d.data()))
          .toList();
      final analytics = ProviderAnalytics(
        all,
        custom?.start ?? DateTime(now.year, now.month, now.day - days + 1),
        custom?.end ?? now,
      );
      final previous = analytics.previousRevenue;
      final trend = previous == 0
          ? 'No confirmed revenue in the previous period'
          : '${((analytics.revenue - previous) * 100 / previous).toStringAsFixed(1)}% versus previous equal-length period';
      final pendingAll = all.where((j) => j.completed && !j.paid).toList();
      final services = analytics.byService.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final recent = all.where((j) => j.completed).toList()
        ..sort(
          (a, b) => (b.completionDate ?? DateTime(1970)).compareTo(
            a.completionDate ?? DateTime(1970),
          ),
        );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Business overview'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final length in [7, 30, 90])
                ChoiceChip(
                  label: Text('$length days'),
                  selected: custom == null && days == length,
                  onSelected: (_) => setState(() {
                    days = length;
                    custom = null;
                  }),
                ),
              ActionChip(
                label: Text(custom == null ? 'Custom dates' : 'Change dates'),
                avatar: const Icon(Icons.date_range, size: 16),
                onPressed: chooseDates,
              ),
            ],
          ),
          Text(
            '${_businessDate(analytics.start)}  -  ${_businessDate(analytics.end.subtract(const Duration(days: 1)))}  -  device local dates',
            style: RaText.caption,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                metric(
                  'Confirmed revenue',
                  _businessMoney(analytics.revenue),
                  '${analytics.paid.length} confirmed payments',
                  () => showJobs('Confirmed payments', analytics.paid),
                ),
                metric(
                  'Awaiting confirmation',
                  _businessMoney(analytics.pendingTotal),
                  '${analytics.pending.length} completed invoices',
                  () => showJobs('Unconfirmed invoices', analytics.pending),
                ),
                metric(
                  'Completed jobs',
                  '${analytics.completed.length}',
                  'In selected completion dates',
                  () => showJobs('Completed jobs', analytics.completed),
                ),
                metric(
                  'Average invoice',
                  analytics.completed.isEmpty
                      ? ' - '
                      : _businessMoney(
                          analytics.completed.fold<int>(
                                0,
                                (s, j) => s + j.amount,
                              ) /
                              analytics.completed.length,
                        ),
                  'Completed jobs; includes unpaid',
                  null,
                ),
                metric(
                  'Customer rating',
                  analytics.averageRating?.toStringAsFixed(1) ?? ' - ',
                  '${analytics.ratingCount} rated completed jobs',
                  null,
                ),
                metric(
                  'Cancellation rate',
                  analytics.cancellationRate == null
                      ? ' - '
                      : '${analytics.cancellationRate!.toStringAsFixed(1)}%',
                  '${analytics.cancelled} of completed + cancelled',
                  () => showJobs(
                    'Cancelled jobs',
                    analytics.activity
                        .where((j) => j.status == 'cancelled')
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(trend, style: RaText.caption),
          const SizedBox(height: 12),
          _RevenueGraph(
            analytics: analytics,
            onDay: (day) => showJobs(
              'Confirmed payments  -  ${_businessDate(day)}',
              analytics.paid
                  .where(
                    (j) =>
                        j.revenueDate!.year == day.year &&
                        j.revenueDate!.month == day.month &&
                        j.revenueDate!.day == day.day,
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recorded revenue, not profit. Only provider-confirmed payments count. Older records without a payment date use the completion date; missing completion dates use the request date.',
            style: RaText.caption,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export selected period as CSV'),
            onPressed: () async {
              try {
                final message = await exportProviderReport(
                  analytics.csv,
                  'roadassist-${analytics.start.toIso8601String().substring(0, 10)}-${analytics.end.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}.csv',
                );
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not export the report. Try again.'),
                    ),
                  );
              }
            },
          ),
          const SizedBox(height: 14),
          const Text('Revenue by service', style: RaText.title),
          const Text(
            'Each paid job counts once under its main requested service.',
            style: RaText.caption,
          ),
          if (services.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No confirmed revenue in this period.'),
            ),
          for (final entry in services)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: LinearProgressIndicator(
                value: analytics.revenue == 0
                    ? 0
                    : entry.value / analytics.revenue,
              ),
              trailing: Text(_businessMoney(entry.value)),
              onTap: () => showJobs(
                entry.key,
                analytics.paid.where((j) => j.service == entry.key).toList(),
              ),
            ),
          if (pendingAll.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.pending_actions),
                title: Text(
                  '${_businessMoney(analytics.allPendingTotal)} awaiting confirmation',
                ),
                subtitle: Text(
                  '${pendingAll.length} invoices across all dates. Confirm only after receiving payment.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showJobs('All unconfirmed invoices', pendingAll),
              ),
            ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Recent service reports', style: RaText.title),
            const Text(
              'Live reports on the 10 most recently completed jobs. Older reports remain accessible from History  -  Invoice.',
              style: RaText.caption,
            ),
            for (final job in recent.take(10))
              _ProviderReportNotice(key: ValueKey(job.id), job: job),
          ],
          const SizedBox(height: 18),
        ],
      );
    },
  );
}

class _RevenueGraph extends StatelessWidget {
  const _RevenueGraph({required this.analytics, required this.onDay});
  final ProviderAnalytics analytics;
  final ValueChanged<DateTime> onDay;
  @override
  Widget build(BuildContext context) {
    final entries = analytics.dailyRevenue.entries.toList();
    final maximum = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily confirmed payments', style: RaText.title),
            Text(
              maximum == 0
                  ? 'No confirmed payments yet.'
                  : 'Peak ${_businessMoney(maximum)}  -  tap a day to view jobs',
              style: RaText.caption,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries
                    .map(
                      (entry) => Semantics(
                        label:
                            '${_businessDate(entry.key)}: ${_businessMoney(entry.value)}',
                        button: true,
                        child: Tooltip(
                          message:
                              '${_businessDate(entry.key)}  -  ${_businessMoney(entry.value)}',
                          child: InkWell(
                            onTap: () => onDay(entry.key),
                            child: SizedBox(
                              width: 40,
                              height: 150,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 22,
                                    height: entry.value == 0
                                        ? 2
                                        : 110 * entry.value / maximum,
                                    decoration: BoxDecoration(
                                      color: entry.value == 0
                                          ? Theme.of(context).dividerColor
                                          : raBlue,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${entry.key.day}/${entry.key.month}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderReportNotice extends StatefulWidget {
  const _ProviderReportNotice({super.key, required this.job});
  final ProviderJob job;
  @override
  State<_ProviderReportNotice> createState() => _ProviderReportNoticeState();
}

class _ProviderReportNoticeState extends State<_ProviderReportNotice> {
  late final report = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.job.id)
      .collection('disputes')
      .doc('case')
      .snapshots();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: report,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Text(
          'A recent service report could not load. Check History.',
        );
      final data = snapshot.data?.data();
      if (data == null || data['status'] == 'resolved')
        return const SizedBox.shrink();
      return Card(
        child: ListTile(
          leading: const Icon(Icons.report_problem_outlined, color: raGold),
          title: Text(
            '${widget.job.data['driverName'] ?? 'Driver'}  -  Service report',
          ),
          subtitle: Text(
            '${data['status'].toString().replaceAll('_', ' ')}  -  Invoice ${_businessMoney(widget.job.amount)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(context, DisputeScreen(requestId: widget.job.id)),
        ),
      );
    },
  );
}
