part of '../screens.dart';

class AdminEarningsReportPanel extends StatefulWidget {
  const AdminEarningsReportPanel({super.key});
  @override
  State<AdminEarningsReportPanel> createState() =>
      _AdminEarningsReportPanelState();
}

class _AdminEarningsReportPanelState extends State<AdminEarningsReportPanel> {
  DateTime month = AdminEarningsReport.sriLanka(DateTime.now());
  bool allTime = false, busy = false;
  String? error, provider;
  AdminEarningsReport? report;
  Future<void> chooseMonth() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Choose any date in the report month',
    );
    if (chosen != null && mounted)
      setState(() {
        month = chosen;
        report = null;
        provider = null;
      });
  }

  Future<void> generate() async {
    setState(() {
      busy = true;
      error = null;
      report = null;
      provider = null;
    });
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('requests')
          .orderBy('completedAt');
      if (!allTime) {
        final start = DateTime.utc(
          month.year,
          month.month,
        ).subtract(const Duration(minutes: 330));
        final end = DateTime.utc(
          month.year,
          month.month + 1,
        ).subtract(const Duration(minutes: 330));
        query = query
            .where(
              'completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('completedAt', isLessThan: Timestamp.fromDate(end));
      }
      final records = <Map<String, dynamic>>[];
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        final page =
            await (cursor == null ? query : query.startAfterDocument(cursor))
                .limit(500)
                .get(const GetOptions(source: Source.server));
        for (final doc in page.docs) {
          final data = doc.data();
          records.add({
            ...data,
            'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          });
        }
        if (page.docs.length < 500) break;
        if (records.length >= 50000)
          throw StateError(
            'Too many records for one report. Select a single month.',
          );
        cursor = page.docs.last;
      }
      final result = AdminEarningsReport.aggregate(
        records,
        generatedAt: DateTime.now(),
        month: allTime ? null : month,
      );
      final identities = AdminIdentityService();
      await Future.wait(
        result.rows.map((row) async {
          final identity = await identities.user(row.providerId);
          if (!identity.unavailable &&
              identity.name != 'Account name unavailable')
            row.name = identity.name;
          if (identity.email.isNotEmpty) row.email = identity.email;
          if (identity.phone.isNotEmpty) row.phone = identity.phone;
        }),
      );
      if (mounted) setState(() => report = result);
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is StateError
              ? e.message
              : 'Unable to generate report. Check admin access and internet connection.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> download() async {
    final current = report;
    if (current == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = provider == null
          ? current
          : current.forProvider(provider!);
      final bytes = await AdminEarningsPdfService.generate(selected);
      await InvoicePdfService.download(
        bytes,
        'RoadAssist-Earnings-${current.period.replaceAll(' ', '-')}-${provider == null ? 'All-Providers' : 'Provider'}.pdf',
      );
    } catch (_) {
      if (mounted)
        setState(() => error = 'PDF could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = report;
    final selected = current == null
        ? null
        : provider == null
        ? current
        : current.forProvider(provider!);
    final providers = {
      if (current != null)
        for (final row in current.rows) row.providerId: row.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Provider earnings PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Completed final bills and provider-confirmed payments. This is service value, not app revenue.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: !allTime,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                          allTime = false;
                          report = null;
                          provider = null;
                        }),
                ),
                ChoiceChip(
                  label: const Text('All months'),
                  selected: allTime,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                          allTime = true;
                          report = null;
                          provider = null;
                        }),
                ),
                if (!allTime)
                  OutlinedButton.icon(
                    onPressed: busy ? null : chooseMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(AdminEarningsReport.monthLabel(month)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : generate,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(busy ? 'Preparing report...' : 'Generate report'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (current != null && selected != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: provider ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All providers'),
                  ),
                  for (final entry in providers.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) =>
                          setState(() => provider = value == '' ? null : value),
              ),
              const SizedBox(height: 12),
              Text(
                'Total service earnings: ${AdminEarningsReport.money(selected.billedCents)}',
              ),
              Text(
                'Confirmed payments: ${AdminEarningsReport.money(selected.confirmedCents)}',
              ),
              Text(
                'Unconfirmed: ${AdminEarningsReport.money(selected.billedCents - selected.confirmedCents)}',
              ),
              Text('Completed jobs: ${selected.jobs}'),
              Text('Generated: ${selected.generatedLabel}'),
              if (current.rows.isEmpty)
                const Text('No eligible completed jobs for this period.'),
              if (current.excluded > 0)
                Text('${current.excluded} invalid records excluded.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : download,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download earnings PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
