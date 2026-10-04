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
            if (saving) const LinearProgressIndicator(),
          ],
        );
      },
    ),
  );
}
