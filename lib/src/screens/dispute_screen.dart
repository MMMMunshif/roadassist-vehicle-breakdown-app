part of '../screens.dart';

class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final description = TextEditingController();
  final response = TextEditingController();
  final photos = <String>[];
  String reason = 'extra_charge';
  bool busy = false;
  bool canReport = false;
  late final job = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.requestId);
  late final caseRef = job.collection('disputes').doc('case');
  late final caseStream = caseRef.snapshots();
  static const reasons = {
    'extra_charge': 'Extra money requested',
    'repair_quality': 'Repair problem',
    'incomplete_service': 'Service incomplete',
    'other': 'Other problem',
  };

  @override
  void initState() {
    super.initState();
    unawaited(
      job
          .get()
          .then((snapshot) {
            if (mounted) {
              setState(
                () => canReport =
                    snapshot.data()?['driverId'] ==
                        FirebaseAuth.instance.currentUser?.uid &&
                    snapshot.data()?['status'] == 'completed',
              );
            }
          })
          .catchError((Object error) {}),
    );
  }

  @override
  void dispose() {
    description.dispose();
    response.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this report. Check your connection and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addPhoto() => perform(() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo == null) return;
    final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);
    if (mounted) setState(() => photos.add(encoded));
  });

  Future<void> submit() async {
    if (description.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe the problem in at least 10 characters.'),
        ),
      );
      return;
    }
    await perform(() async {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final request = (await transaction.get(job)).data();
        final existing = await transaction.get(caseRef);
        if (existing.exists ||
            request == null ||
            request['status'] != 'completed' ||
            request['driverId'] != FirebaseAuth.instance.currentUser?.uid)
          throw StateError('Unavailable');
        transaction.set(caseRef, {
          'driverId': request['driverId'],
          'providerId': request['providerId'],
          'reason': reason,
          'description': description.text.trim(),
          'photos': List<String>.from(photos),
          'status': 'open',
          'providerResponse': '',
          'resolution': '',
          'approvedTotal': request['estimatedCost'] ?? 0,
          'finalTotal': request['finalCost'] ?? request['estimatedCost'] ?? 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  Future<void> reply() async {
    if (response.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a response of at least 10 characters.'),
        ),
      );
      return;
    }
    await perform(
      () => caseRef.update({
        'providerResponse': response.text.trim(),
        'status': 'under_review',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> resolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Has the problem been resolved?'),
        content: const Text(
          'Confirm only if you are satisfied with the resolution. This records your confirmation; it does not change the invoice or process a refund.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm resolved'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await perform(
      () => caseRef.update({
        'status': 'resolved',
        'resolution': 'Driver confirmed the problem is resolved.',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Service problem report')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: caseStream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text('Could not load this report. Please reconnect.'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final report = snapshot.data!.data();
        final uid = FirebaseAuth.instance.currentUser?.uid;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Job ${widget.requestId}', style: RaText.title),
            const SizedBox(height: 12),
            const Text(
              'Reports are shared with the assigned provider. Avoid including unrelated personal information. No automatic refund is issued.',
            ),
            const SizedBox(height: 16),
            if (report == null && canReport) ...[
              const Text(
                'Drivers can report a problem after service completion.',
              ),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Problem'),
                items: reasons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() => reason = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                enabled: !busy,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'What happened?'),
              ),
              RevisionEvidencePhotos(photos: photos),
              for (var i = 0; i < photos.length; i++)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => photos.removeAt(i)),
                  child: Text('Remove photo ${i + 1}'),
                ),
              OutlinedButton.icon(
                onPressed: busy || photos.length >= 2 ? null : addPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add evidence photo (up to 2)'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: const Text('Submit report'),
              ),
            ] else if (report != null) ...[
              SummaryRow(
                'Status',
                report['status'].toString().replaceAll('_', ' ').toUpperCase(),
              ),
              SummaryRow(
                'Problem',
                reasons[report['reason']] ?? 'Other problem',
              ),
              Text(report['description'] as String),
              const SizedBox(height: 12),
              RevisionEvidencePhotos(
                photos: List<String>.from(report['photos'] as List),
              ),
              SummaryRow(
                'Approved total at reporting',
                'Rs. ${report['approvedTotal']}',
              ),
              SummaryRow(
                'Final invoice at reporting',
                'Rs. ${report['finalTotal']}',
              ),
              if ((report['providerResponse'] as String).isNotEmpty) ...[
                const Divider(),
                const Text('Provider response', style: RaText.title),
                Text(report['providerResponse'] as String),
              ],
              if (report['status'] != 'resolved' &&
                  uid == report['providerId']) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: response,
                  enabled: !busy,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Your response / proposed resolution',
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : reply,
                  child: const Text('Send response'),
                ),
              ],
              if (report['status'] != 'resolved' && uid == report['driverId'])
                FilledButton(
                  onPressed: busy ? null : resolve,
                  child: const Text('Confirm problem resolved'),
                ),
              if (report['status'] == 'resolved')
                Text(report['resolution'] as String),
              OutlinedButton(
                onPressed: () =>
                    push(context, InvoiceScreen(requestId: widget.requestId)),
                child: const Text('View invoice and approval history'),
              ),
            ],
            if (report == null && !canReport)
              const Text(
                'No driver problem report has been submitted for this job.',
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        );
      },
    ),
  );
}
