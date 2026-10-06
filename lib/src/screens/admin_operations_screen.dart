part of '../screens.dart';

class _AdminOperationsPanel extends StatefulWidget {
  const _AdminOperationsPanel({super.key, required this.mode});
  final String mode;
  @override
  State<_AdminOperationsPanel> createState() => _AdminOperationsPanelState();
}

class _AdminOperationsPanelState extends State<_AdminOperationsPanel> {
  int limit = 100;
  Timer? clock;
  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  bool attentionOnly = true;
  late Stream<QuerySnapshot<Map<String, dynamic>>> jobs;
  @override
  void initState() {
    super.initState();
    connect();
    clock?.cancel();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void connect() {
    jobs = FirebaseFirestore.instance
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  String csvCell(Object? value) {
    var text = '${value ?? ''}';
    if (RegExp(r'^\s*[=+@\-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: jobs,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(
          child: Text('Unable to load operations. Check admin access.'),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs;
      final completed = docs
          .where((d) => d.data()['status'] == 'completed')
          .toList();
      final confirmed = completed
          .where((d) => d.data()['providerConfirmedPayment'] == true)
          .toList();
      final reported = completed
          .where(
            (d) =>
                d.data()['driverReportedPayment'] == true &&
                d.data()['providerConfirmedPayment'] != true,
          )
          .toList();
      final unpaid = completed
          .where(
            (d) =>
                d.data()['driverReportedPayment'] != true &&
                d.data()['providerConfirmedPayment'] != true,
          )
          .toList();
      final waiting = docs
          .where(
            (d) =>
                d.data()['status'] == 'searching' &&
                DateTime.now()
                        .difference(
                          (d.data()['createdAt'] is Timestamp
                              ? (d.data()['createdAt'] as Timestamp).toDate()
                              : DateTime.now()),
                        )
                        .inMinutes >=
                    15,
          )
          .toList();
      final stalled = docs
          .where(
            (d) =>
                [
                  'accepted',
                  'en_route',
                  'arrived',
                ].contains(d.data()['status']) &&
                DateTime.now()
                        .difference(
                          ((d.data()['updatedAt'] ?? d.data()['createdAt'])
                                  as Timestamp)
                              .toDate(),
                        )
                        .inMinutes >=
                    60,
          )
          .toList();
      final shown = widget.mode == 'payments'
          ? completed
                .where(
                  (d) =>
                      !attentionOnly ||
                      d.data()['providerConfirmedPayment'] != true,
                )
                .toList()
          : widget.mode == 'operations'
          ? [...waiting, ...stalled]
          : docs;
      final total = confirmed.fold<double>(
        0,
        (sum, d) =>
            sum +
            ((d.data()['finalCost'] ?? d.data()['estimatedCost'] ?? 0) as num)
                .toDouble(),
      );
      final cancelled = docs
          .where((d) => d.data()['status'] == 'cancelled')
          .length;
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Text(
            '${docs.length} recent jobs loaded. Metrics and exports cover these records only; not lifetime totals.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final metric
                  in widget.mode == 'operations'
                      ? [
                          ('Waiting 15+ minutes', '${waiting.length}'),
                          ('No update 60+ minutes', '${stalled.length}'),
                        ]
                      : [
                          ('Completed', '${completed.length}'),
                          ('Payment confirmed', '${confirmed.length}'),
                          ('Driver reported only', '${reported.length}'),
                          ('Not reported paid', '${unpaid.length}'),
                          (
                            'Confirmed invoice value',
                            'Rs. ${total.toStringAsFixed(0)}',
                          ),
                          (
                            'Cancellation rate',
                            docs.isEmpty
                                ? '0%'
                                : '${(100 * cancelled / docs.length).toStringAsFixed(1)}%',
                          ),
                        ])
                SizedBox(
                  width: 210,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.$1),
                          const SizedBox(height: 12),
                          Text(metric.$2, style: RaText.numeric),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.mode == 'operations')
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('complaintReviews')
                  .limit(100)
                  .snapshots(),
              builder: (context, cases) {
                if (cases.hasError)
                  return const Text('Could not load complaint follow-ups.');
                final overdue = (cases.data?.docs ?? [])
                    .where(
                      (d) =>
                          d.data()['status'] == 'under_review' &&
                          ((d.data()['dueAt'] as Timestamp?)?.toDate().isBefore(
                                DateTime.now(),
                              ) ??
                              false),
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Overdue complaint follow-ups: ${overdue.length} (up to 100 reviews loaded)',
                      style: RaText.title,
                    ),
                    for (final d in overdue)
                      Card(
                        child: ListTile(
                          title: Text('Case ${d.id}'),
                          subtitle: Text('Priority: ${d.data()['priority']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => push(
                            context,
                            _AdminComplaintScreen(requestId: d.id),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (widget.mode == 'payments')
            SwitchListTile(
              title: const Text('Only payments needing confirmation'),
              value: attentionOnly,
              onChanged: (v) => setState(() => attentionOnly = v),
            ),
          if (widget.mode == 'operations')
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These are review prompts, not automatic misconduct findings. Open a job to inspect it and contact participants. No price or assignment is changed here.',
              ),
            ),
          if (widget.mode == 'reports') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export loaded job report'),
              onPressed: () async {
                final csv = [
                  'job,status,service,approved_amount,final_amount,payment_confirmed,created_at',
                  for (final d in docs)
                    [
                      d.id,
                      d.data()['status'],
                      requestIssueLabel(d.data()),
                      d.data()['estimatedCost'],
                      d.data()['finalCost'],
                      d.data()['providerConfirmedPayment'] == true,
                      (d.data()['createdAt'] as Timestamp?)
                          ?.toDate()
                          .toIso8601String(),
                    ].map(csvCell).join(','),
                ].join('\r\n');
                final result = await exportProviderReport(
                  csv,
                  'roadassist-admin-jobs.csv',
                );
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result)));
              },
            ),
            const SizedBox(height: 16),
            const Text('Service mix in loaded jobs', style: RaText.title),
            for (final service in [
              'General Mechanic',
              'Vehicle Towing',
              'Flat Tyre',
              'Battery Jumpstart',
            ])
              ListTile(
                title: Text(service),
                trailing: Text(
                  '${docs.where((d) => d.data()['issue'] == service).length}',
                ),
              ),
          ],
          if (widget.mode != 'reports') ...[
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No jobs need attention in the loaded records.'),
                ),
              ),
            for (final d in shown)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text('${d.data()['driverName'] ?? d.id}'),
                  subtitle: Text(
                    '${d.data()['providerName'] ?? 'Unassigned'}\n${requestIssueLabel(d.data())}\n${widget.mode == 'payments'
                        ? d.data()['providerConfirmedPayment'] == true
                              ? 'Provider confirmed receipt'
                              : d.data()['driverReportedPayment'] == true
                              ? 'Driver reports paid; receipt not confirmed'
                              : 'Payment not reported'
                        : 'Review last update and contact participants'}',
                  ),
                  isThreeLine: true,
                  trailing: _AdminStatusBadge(status: '${d.data()['status']}'),
                  onTap: () => push(
                    context,
                    widget.mode == 'payments'
                        ? InvoiceScreen(requestId: d.id)
                        : AdminJobMonitorScreen(requestId: d.id),
                  ),
                ),
              ),
          ],
          if (docs.length == limit)
            OutlinedButton(
              onPressed: () => setState(() {
                limit += 100;
                connect();
                clock?.cancel();
                clock = Timer.periodic(const Duration(minutes: 1), (_) {
                  if (mounted) setState(() {});
                });
              }),
              child: const Text('Load 100 more jobs'),
            ),
        ],
      );
    },
  );
}

class _AdminSettingsPanel extends StatefulWidget {
  const _AdminSettingsPanel();
  @override
  State<_AdminSettingsPanel> createState() => _AdminSettingsPanelState();
}

class _AdminSettingsPanelState extends State<_AdminSettingsPanel> {
  final notice = TextEditingController(), coverage = TextEditingController();
  final services = <String>{
    'General Mechanic',
    'Vehicle Towing',
    'Flat Tyre',
    'Battery Jumpstart',
  };
  bool maintenance = false, loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final d =
          (await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('operations')
                  .get())
              .data();
      if (d != null) {
        notice.text = d['notice'] as String;
        coverage.text = d['coverage'] as String;
        services
          ..clear()
          ..addAll((d['enabledServices'] as List).cast<String>());
        maintenance = d['maintenance'] == true;
      }
    } catch (_) {
      error = 'Unable to load settings.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    notice.dispose();
    coverage.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final reason = await _adminReason(
      context,
      'Reason for changing app settings',
    );
    if (reason == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AdminService().saveSettings(
        maintenance: maintenance,
        notice: notice.text.trim(),
        coverage: coverage.text.trim(),
        services: services.toList(),
        reason: reason,
      );
      if (mounted) setState(() => error = 'Settings saved.');
    } catch (_) {
      if (mounted)
        setState(
          () =>
              error = 'Settings not saved. Super admin permission is required.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Service availability', style: RaText.headline),
            const Text(
              'Maintenance pauses new requests. Existing jobs, messages and invoices remain accessible. Service settings apply to new assistance requests.',
            ),
            SwitchListTile(
              title: const Text('Pause new assistance requests'),
              value: maintenance,
              onChanged: busy ? null : (v) => setState(() => maintenance = v),
            ),
            TextField(
              controller: notice,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Public service notice (no personal details)',
              ),
            ),
            TextField(
              controller: coverage,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText:
                    'Coverage description (informational; not a geofence)',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final service in [
                  'General Mechanic',
                  'Vehicle Towing',
                  'Flat Tyre',
                  'Battery Jumpstart',
                ])
                  FilterChip(
                    label: Text(service),
                    selected: services.contains(service),
                    onSelected: busy
                        ? null
                        : (v) => setState(() {
                            if (v) {
                              services.add(service);
                            } else {
                              services.remove(service);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: const Text('Save with audit record'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
          ],
        );
}

class _AdminTeamPanel extends StatelessWidget {
  const _AdminTeamPanel();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('adminAccess')
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(
          child: Text('Super admin access is required for team records.'),
        );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Admin team permissions', style: RaText.headline),
          const Text(
            'Super admin: settings, users, verification and cases. Reviewer: provider documents and verification. Support: complaints and job/payment monitoring. Owner provisioning is required to grant or revoke access; there is no public admin signup.',
          ),
          for (final d
              in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            Card(
              child: ListTile(
                title: Text('${d.data()['email'] ?? d.id}'),
                subtitle: Text('${d.data()['role'] ?? 'super_admin'}'),
                trailing: _AdminStatusBadge(
                  status: d.data()['enabled'] == true ? 'active' : 'revoked',
                ),
              ),
            ),
        ],
      );
    },
  );
}
