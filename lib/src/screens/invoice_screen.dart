part of '../screens.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> request;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    request = RequestService().watchRequest(widget.requestId);
  }

  Future<void> record(String method) async {
    setState(() => saving = true);
    try {
      await RequestService().recordPayment(widget.requestId, method);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Service Invoice')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: request,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text('Could not load invoice. Please reconnect.'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data();
        if (data == null || data['status'] != 'completed')
          return const Center(
            child: Text(
              'The final invoice is available after service completion.',
            ),
          );
        final approved = (data['estimatedCost'] as num?)?.toInt() ?? 0;
        final total = (data['finalCost'] as num?)?.toInt() ?? approved;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final provider = uid == data['providerId'];
        final driver = uid == data['driverId'];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Job ${widget.requestId}', style: RaText.title),
            SummaryRow('Provider', data['providerName'] as String? ?? ''),
            SummaryRow('Vehicle', data['modelYear'] as String? ?? ''),
            SummaryRow('Registration', data['registration'] as String? ?? ''),
            SummaryRow('Reported problem', requestIssueLabel(data)),
            if (data['providerDiagnosis'] is String)
              SummaryRow(
                'Diagnosis / approved work',
                data['providerDiagnosis'] as String,
              ),
            const Divider(),
            SummaryRow('Service / labour', 'Rs. ${data['serviceFee'] ?? 0}'),
            SummaryRow('Travel', 'Rs. ${data['dispatchFee'] ?? 0}'),
            SummaryRow(
              'Parts / other approved charges',
              'Rs. ${data['extraFee'] ?? 0}',
            ),
            if (total < approved)
              SummaryRow('Discount', 'Rs. ${approved - total}'),
            SummaryRow('Final total', 'Rs. $total', strong: true),
            const Divider(),
            Text(
              data['providerConfirmedPayment'] == true
                  ? 'Provider confirmed payment received'
                  : data['driverReportedPayment'] == true
                  ? 'Driver reported payment — awaiting provider confirmation'
                  : 'Payment not recorded',
            ),
            if (data['paymentMethod'] is String)
              Text('Method: ${data['paymentMethod']}'),
            const Text(
              'Cash and external payments are recorded manually. This app does not process an online payment.',
            ),
            if (driver && data['driverReportedPayment'] != true) ...[
              const SizedBox(height: 16),
              const Text('Only record payment after you have actually paid.'),
              OutlinedButton(
                onPressed: saving ? null : () => record('cash'),
                child: const Text('I Paid Cash'),
              ),
              OutlinedButton(
                onPressed: saving ? null : () => record('external'),
                child: const Text('I Paid Outside the App'),
              ),
            ],
            if (provider &&
                data['driverReportedPayment'] == true &&
                data['providerConfirmedPayment'] != true)
              FilledButton(
                onPressed: saving
                    ? null
                    : () => record(data['paymentMethod'] as String),
                child: const Text('Confirm Payment Received'),
              ),
            const SizedBox(height: 16),
            if (driver || provider)
              OutlinedButton.icon(
                onPressed: () =>
                    push(context, DisputeScreen(requestId: widget.requestId)),
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(
                  driver
                      ? 'Report a problem / View report'
                      : 'View service problem report',
                ),
              ),
            if (saving) const LinearProgressIndicator(),
            if (data['workflowVersion'] == 2)
              _InvoiceApprovalHistory(
                requestId: widget.requestId,
                selectedQuoteId: data['selectedQuoteId'] as String?,
              ),
          ],
        );
      },
    ),
  );
}

class _InvoiceApprovalHistory extends StatefulWidget {
  const _InvoiceApprovalHistory({
    required this.requestId,
    this.selectedQuoteId,
  });
  final String requestId;
  final String? selectedQuoteId;
  @override
  State<_InvoiceApprovalHistory> createState() =>
      _InvoiceApprovalHistoryState();
}

class _InvoiceApprovalHistoryState extends State<_InvoiceApprovalHistory> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> revisions;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> decisions;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? initialQuote;
  @override
  void initState() {
    super.initState();
    final ref = FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId);
    revisions = ref.collection('repairQuotes').snapshots();
    decisions = ref.collection('repairDecisions').snapshots();
    initialQuote = widget.selectedQuoteId == null
        ? null
        : ref.collection('quotes').doc(widget.selectedQuoteId).snapshots();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const Text('Quote and approval history', style: RaText.title),
      const Text('Rejected or unapproved proposals are not added to the bill.'),
      if (initialQuote != null)
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: initialQuote,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text('Could not load the original quote.');
            final quote = snapshot.data?.data();
            if (quote == null) return const LinearProgressIndicator();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Original approved ${quote['quoteType'] == 'inspection' ? 'inspection' : 'service'} offer: Rs. ${quote['total']}',
              ),
              subtitle: Text('Included work / exclusions: ${quote['notes']}'),
            );
          },
        ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: decisions,
        builder: (context, decisionSnapshot) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: revisions,
              builder: (context, revisionSnapshot) {
                if (revisionSnapshot.hasError || decisionSnapshot.hasError)
                  return const Text('Could not load approval history.');
                if (!revisionSnapshot.hasData || !decisionSnapshot.hasData)
                  return const LinearProgressIndicator();
                final outcomes = {
                  for (final d in decisionSnapshot.data!.docs) d.id: d.data(),
                };
                final entries = revisionSnapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => (a.data()['createdAt'] as Timestamp).compareTo(
                      b.data()['createdAt'] as Timestamp,
                    ),
                  );
                if (entries.isEmpty)
                  return const Text('No repair revisions were proposed.');
                return Column(
                  children: entries.map((entry) {
                    final revision = entry.data();
                    final decision = outcomes[entry.id];
                    final outcome =
                        decision?['decision'] as String? ?? 'not approved';
                    final date =
                        (decision?['createdAt'] as Timestamp? ??
                                revision['createdAt'] as Timestamp)
                            .toDate()
                            .toLocal();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            outcome == 'approved'
                                ? Icons.check_circle_outline
                                : outcome == 'rejected'
                                ? Icons.cancel_outlined
                                : Icons.hourglass_empty,
                          ),
                          title: Text(
                            '${outcome.toUpperCase()}: Rs. ${revision['previousTotal']} to Rs. ${revision['total']}',
                          ),
                          subtitle: Text(
                            '${revision['diagnosisAndWork']}\nReason: ${revision['changeReason'] ?? 'Not recorded for this older revision'}\n${date.toString().split('.').first}',
                          ),
                        ),
                        RevisionEvidencePhotos(
                          photos: List<String>.from(
                            revision['evidencePhotoData'] as List? ?? [],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
      ),
    ],
  );
}
