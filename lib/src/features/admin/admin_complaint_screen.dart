part of '../../screens.dart';

class _AdminComplaintScreen extends StatefulWidget {
  const _AdminComplaintScreen({required this.requestId});
  final String requestId;
  @override
  State<_AdminComplaintScreen> createState() => _AdminComplaintScreenState();
}

class _AdminComplaintScreenState extends State<_AdminComplaintScreen> {
  String priority = 'normal';
  DateTime dueAt = DateTime.now().add(const Duration(days: 2));
  bool busy = false;
  late final review = FirebaseFirestore.instance
      .collection('complaintReviews')
      .doc(widget.requestId)
      .snapshots();
  Future<void> decide(String status) async {
    final reason = await _adminReason(context, 'Public decision / next step');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().reviewComplaint(
        widget.requestId,
        status: status,
        priority: priority,
        dueAt: dueAt,
        decision: reason,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the decision.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complaint review')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Review evidence, the invoice and both replies before deciding. Decisions are visible to both participants and do not process refunds.',
        ),
        OutlinedButton(
          onPressed: () =>
              push(context, DisputeScreen(requestId: widget.requestId)),
          child: const Text('View driver report, photos and provider response'),
        ),
        OutlinedButton(
          onPressed: () =>
              push(context, InvoiceScreen(requestId: widget.requestId)),
          child: const Text('View invoice and approval evidence'),
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: review,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text('Could not load admin review.');
            final data = snapshot.data?.data();
            return Column(
              children: [
                SummaryRow(
                  'Admin review',
                  data?['status'] as String? ?? 'not assigned',
                ),
                SummaryRow(
                  'Assigned admin',
                  data?['assignedTo'] as String? ?? 'none',
                ),
                SummaryRow(
                  'Priority',
                  data?['priority'] as String? ?? 'normal',
                ),
                if (data?['dueAt'] is Timestamp)
                  Text(
                    'Follow-up deadline: ${(data!['dueAt'] as Timestamp).toDate().toLocal()}',
                  ),
                if (data?['decision'] is String)
                  Text(data!['decision'] as String),
              ],
            );
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: priority,
          decoration: const InputDecoration(
            labelText: 'Priority for next action',
          ),
          items: [
            for (final value in ['low', 'normal', 'high', 'urgent'])
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: busy ? null : (value) => setState(() => priority = value!),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null && mounted)
                    setState(
                      () => dueAt = picked.add(
                        const Duration(hours: 23, minutes: 59),
                      ),
                    );
                },
          child: Text(
            'Follow-up deadline: ${dueAt.toLocal().toString().split(' ').first}',
          ),
        ),
        const Text(
          'Start review also reopens an existing resolved review; give a reason.',
        ),
        for (final status in ['under_review', 'resolved', 'dismissed'])
          OutlinedButton(
            onPressed: busy ? null : () => decide(status),
            child: Text(
              status == 'under_review'
                  ? 'Assign to me / Start review'
                  : status == 'resolved'
                  ? 'Record resolution'
                  : 'Dismiss with reason',
            ),
          ),
        _AdminPrivateNotes(kind: 'complaint', target: widget.requestId),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
