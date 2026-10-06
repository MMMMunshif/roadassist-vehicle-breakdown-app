part of '../../screens.dart';

class AdminJobMonitorScreen extends StatefulWidget {
  const AdminJobMonitorScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<AdminJobMonitorScreen> createState() => _AdminJobMonitorScreenState();
}

class _AdminJobMonitorScreenState extends State<AdminJobMonitorScreen> {
  late final job = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.requestId)
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job monitor')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: job,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Could not load job.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data();
        if (data == null) return const Center(child: Text('Job not found.'));
        final updated = (data['updatedAt'] as Timestamp?)?.toDate();
        final active = [
          'accepted',
          'en_route',
          'arrived',
        ].contains(data['status']);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.requestId, style: RaText.title),
            SummaryRow('Status', data['status'] as String? ?? ''),
            Wrap(
              spacing: 8,
              children: [
                if ((data['driverPhone'] as String? ?? '').isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call driver'),
                    onPressed: () => showCallPrompt(
                      context,
                      name: 'driver',
                      number: data['driverPhone'] as String,
                    ),
                  ),
                if ((data['providerPhone'] as String? ?? '').isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call provider'),
                    onPressed: () => showCallPrompt(
                      context,
                      name: 'provider',
                      number: data['providerPhone'] as String,
                    ),
                  ),
              ],
            ),
            if (active && data['providerId'] is String)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('providerDirectory')
                    .doc(data['providerId'] as String)
                    .snapshots(),
                builder: (context, presence) {
                  if (presence.hasError || !presence.hasData)
                    return const SizedBox.shrink();
                  return Text(
                    presence.data?.data()?['online'] == true
                        ? 'Assigned provider availability: online'
                        : 'Assigned provider availability: offline. Contact the provider if a job update is overdue.',
                  );
                },
              ),
            SummaryRow('Driver', data['driverName'] as String? ?? ''),
            SummaryRow(
              'Provider',
              data['providerName'] as String? ?? 'Unassigned',
            ),
            SummaryRow('Vehicle', data['modelYear'] as String? ?? ''),
            SummaryRow('Problem', requestIssueLabel(data)),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Not recorded',
            ),
            SummaryRow('Approved amount', 'Rs. ${data['estimatedCost'] ?? 0}'),
            if (updated != null)
              Text('Last recorded update: ${updated.toLocal()}'),
            if (active &&
                updated != null &&
                DateTime.now().difference(updated).inMinutes >= 60)
              const Text(
                'No recorded update for at least an hour. Review the situation; this alone does not establish a problem.',
              ),
            if (data['description'] is String)
              Text(data['description'] as String),
            if (data['status'] == 'completed')
              OutlinedButton(
                onPressed: () =>
                    push(context, InvoiceScreen(requestId: widget.requestId)),
                child: const Text('Review invoice and approvals'),
              ),
            const Text(
              'Monitoring is read-only. Contact the relevant participants through your agreed support process.',
            ),
          ],
        );
      },
    ),
  );
}
