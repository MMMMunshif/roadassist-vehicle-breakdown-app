part of '../screens.dart';

Future<String?> requestCancellationReason(
  BuildContext context, {
  bool changingProvider = false,
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => _CancellationSheet(changingProvider: changingProvider),
);

class _CancellationSheet extends StatefulWidget {
  const _CancellationSheet({required this.changingProvider});
  final bool changingProvider;
  @override
  State<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends State<_CancellationSheet> {
  String selected = 'Assistance is no longer needed';
  final details = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.changingProvider) selected = 'I want to choose another provider';
  }

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      20,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.changingProvider
              ? 'Choose another provider?'
              : 'Cancel assistance?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.changingProvider
              ? 'The current request will be cancelled before you choose a provider and review the new visit fee.'
              : 'Your provider will be notified. This request stays in your history.',
        ),
        const SizedBox(height: 12),
        const InlineMessage(
          icon: Icons.receipt_long_outlined,
          text:
              'No cancellation fee is added by this action. Payments already made are not automatically refunded.',
        ),
        const SizedBox(height: 12),
        for (final reason in const [
          'Assistance is no longer needed',
          'The provider is taking too long',
          'I want to choose another provider',
          'Other reason',
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(reason),
            leading: Icon(
              selected == reason
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onTap: () => setState(() => selected = reason),
          ),
        if (selected == 'Other reason')
          TextField(
            controller: details,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tell us what happened',
              helperText: 'At least 10 characters',
            ),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              selected == 'Other reason' && details.text.trim().length < 10
              ? null
              : () => Navigator.pop(
                  context,
                  selected == 'Other reason' ? details.text.trim() : selected,
                ),
          child: Text(
            widget.changingProvider
                ? 'Cancel & choose provider'
                : 'Confirm cancellation',
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep request'),
        ),
      ],
    ),
  );
}

class WorkApprovalPanel extends StatefulWidget {
  const WorkApprovalPanel({
    super.key,
    required this.requestId,
    this.isProvider = false,
    this.onPrepare,
  });
  final String requestId;
  final bool isProvider;
  final Future<void> Function()? onPrepare;
  @override
  State<WorkApprovalPanel> createState() => _WorkApprovalPanelState();
}

class _WorkApprovalPanelState extends State<WorkApprovalPanel> {
  bool busy = false;
  Future<void> decide(Map estimate, bool approve) async {
    setState(() => busy = true);
    try {
      await VisitBillingService().send('decide_estimate', {
        'requestId': widget.requestId,
        'revision': estimate['revision'],
        'approve': approve,
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _workflowError(error, 'Unable to review this estimate.'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: RequestService().watchRequest(widget.requestId),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const InlineMessage(
          icon: Icons.cloud_off_outlined,
          text:
              'Work approval could not load. Reconnect before starting extra work.',
        );
      final job = snapshot.data?.data();
      if (job == null ||
          job['workflowVersion'] != 3 ||
          job['status'] != 'arrived' ||
          job['completionState'] == 'pending')
        return const SizedBox.shrink();
      final estimate = job['workEstimate'] as Map?;
      if (estimate == null && !widget.isProvider)
        return const SizedBox.shrink();
      final pending = estimate?['status'] == 'pending';
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pending
                    ? 'Extra work needs approval'
                    : estimate?['status'] == 'approved'
                    ? 'Work approved'
                    : estimate?['status'] == 'declined'
                    ? 'Estimate declined'
                    : 'Parts or extra work?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (estimate != null) ...[
                Text(
                  'Total including visit: Rs. ${estimate['finalCost']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(estimate['serviceNotes']?.toString() ?? ''),
                ExpansionTile(
                  title: const Text('View charges'),
                  children: [
                    FinalBillBreakdown(data: {...job, ...estimate}),
                  ],
                ),
              ] else
                const Text(
                  'Agree replacement parts and any extra work with the driver before starting. Normal service can go straight to the final bill.',
                ),
              if (pending && !widget.isProvider) ...[
                const Text(
                  'Approve only the work and amounts you agree to. You pay after the service.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : () => decide(estimate!, true),
                  child: const Text('Approve work'),
                ),
                TextButton(
                  onPressed: busy ? null : () => decide(estimate!, false),
                  child: const Text('Decline extra work'),
                ),
              ],
              if (pending && widget.isProvider)
                const Text(
                  'Waiting for the driver. Do not start the extra work yet.',
                ),
              if (widget.isProvider &&
                  !pending &&
                  job['serviceCompletedAt'] == null)
                OutlinedButton.icon(
                  onPressed: busy ? null : widget.onPrepare,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    estimate == null
                        ? 'Agree work & parts'
                        : 'Revise work estimate',
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    },
  );
}

class ProviderPaymentFollowUps extends StatelessWidget {
  const ProviderPaymentFollowUps({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: RequestService().watchProviderRequests(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const InlineMessage(
          icon: Icons.cloud_off_outlined,
          text:
              'Payment follow-ups could not load. Open Jobs to check your invoices.',
        );
      final jobs =
          snapshot.data?.docs.where((doc) {
            final d = doc.data();
            return (d['serviceCompletedAt'] != null ||
                    d['status'] == 'completed') &&
                d['providerConfirmedPayment'] != true &&
                d['demoPayment'] == null &&
                d['status'] != 'cancelled';
          }).toList() ??
          [];
      if (jobs.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Payment follow-ups (${jobs.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Finished visits stay here until payment is confirmed.',
              ),
              for (final doc in jobs.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(doc.data()['driverName']?.toString() ?? 'Driver'),
                  subtitle: Text(
                    'Rs. ${doc.data()['finalCost']} • ${doc.data()['driverReportedPayment'] == true ? 'Driver reported payment' : 'Awaiting driver review'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => push(
                    context,
                    doc.data()['status'] == 'completed'
                        ? InvoiceScreen(requestId: doc.id)
                        : ProviderActiveJobScreen(
                            requestId: doc.id,
                            requestData: doc.data(),
                          ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
