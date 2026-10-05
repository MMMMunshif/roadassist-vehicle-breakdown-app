part of '../screens.dart';

class RepairQuotePanel extends StatefulWidget {
  const RepairQuotePanel({
    super.key,
    required this.requestId,
    this.isProvider = false,
  });
  final String requestId;
  final bool isProvider;
  @override
  State<RepairQuotePanel> createState() => _RepairQuotePanelState();
}

class _RepairQuotePanelState extends State<RepairQuotePanel> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> request;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    request = RequestService().watchRequest(widget.requestId);
  }

  Future<void> act(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: request,
    builder: (context, snapshot) {
      final data = snapshot.data?.data();
      if (data == null ||
          data['workflowVersion'] != 2 ||
          data['status'] != 'arrived')
        return const SizedBox.shrink();
      final pending = data['pendingRepairId'] as String?;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Repair approval', style: RaText.title),
              Text('Currently approved total: Rs. ${data['estimatedCost']}'),
              if (data['approvedQuoteType'] == 'inspection' &&
                  data['approvedRepairId'] == null)
                const Text(
                  'The visit and inspection are approved. Repair work is not yet authorized.',
                ),
              if (data['providerDiagnosis'] is String)
                Text('Provider diagnosis / work: ${data['providerDiagnosis']}'),
              if (pending != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .doc(widget.requestId)
                      .collection('repairQuotes')
                      .doc(pending)
                      .snapshots(),
                  builder: (context, revision) {
                    if (revision.hasError)
                      return const Text(
                        'Could not load the repair quote. Please reconnect.',
                      );
                    final offer = revision.data?.data();
                    if (offer == null) return const LinearProgressIndicator();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Reason, proposed work and parts',
                          style: RaText.label,
                        ),
                        Text(offer['diagnosisAndWork'] as String),
                        if (offer['changeReason'] is String)
                          Text('Reason: ${offer['changeReason']}'),
                        RevisionEvidencePhotos(
                          photos: List<String>.from(
                            offer['evidencePhotoData'] as List? ?? [],
                          ),
                        ),
                        SummaryRow(
                          'Previously approved',
                          'Rs. ${offer['previousTotal']}',
                        ),
                        SummaryRow(
                          (offer['total'] as num) >=
                                  (offer['previousTotal'] as num)
                              ? 'Additional amount requested'
                              : 'Reduction requested',
                          'Rs. ${((offer['total'] as num) - (offer['previousTotal'] as num)).abs()}',
                        ),
                        SummaryRow(
                          'Service / labour',
                          'Rs. ${offer['serviceFee']}',
                        ),
                        SummaryRow('Travel', 'Rs. ${offer['travelFee']}'),
                        SummaryRow(
                          'Parts / other stated charges',
                          'Rs. ${offer['extraFee']}',
                        ),
                        SummaryRow(
                          'Revised full total',
                          'Rs. ${offer['total']}',
                          strong: true,
                        ),
                        const Text(
                          'This replaces the previous total; it is not an additional bill.',
                        ),
                        if (widget.isProvider)
                          const Text(
                            'Waiting for driver approval. Do not perform the proposed work yet.',
                          )
                        else ...[
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text(
                                          'Approve repair and revised total?',
                                        ),
                                        content: Text(
                                          'Previous total: Rs. ${offer['previousTotal']}. New total: Rs. ${offer['total']}.\n\nWork: ${offer['diagnosisAndWork']}\n\nApprove only if you agree to this work and the new full bill.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Back'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Approve'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (yes == true && mounted)
                                      await act(
                                        () => RequestService().decideRepair(
                                          widget.requestId,
                                          pending,
                                          true,
                                        ),
                                      );
                                  },
                            child: const Text('Approve Repair'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => act(
                                    () => RequestService().decideRepair(
                                      widget.requestId,
                                      pending,
                                      false,
                                    ),
                                  ),
                            child: const Text('Reject Proposed Work'),
                          ),
                          TextButton.icon(
                            onPressed: () => push(
                              context,
                              ChatScreen(
                                requestId: widget.requestId,
                                peerName:
                                    data['providerName'] as String? ??
                                    'Provider',
                                peerPhone:
                                    data['providerPhone'] as String? ?? '',
                              ),
                            ),
                            icon: const Icon(Icons.chat_outlined),
                            label: const Text('Discuss with provider'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              if (widget.isProvider && pending == null)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final quote = await requestProviderQuote(context, {
                            ...data,
                            'repairRevision': true,
                          });
                          if (quote != null && mounted)
                            await act(
                              () => RequestService().proposeRepair(
                                widget.requestId,
                                quote,
                              ),
                            );
                        },
                  child: Text(
                    data['approvedQuoteType'] == 'inspection' &&
                            data['approvedRepairId'] == null
                        ? 'Submit Repair Quote'
                        : 'Request Price / Work Change',
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

class RevisionEvidencePhotos extends StatelessWidget {
  const RevisionEvidencePhotos({super.key, required this.photos});
  final List<String> photos;
  Widget image(String photo, {bool thumbnail = false}) {
    try {
      return Image.memory(
        base64Decode(photo),
        width: thumbnail ? 110 : null,
        height: thumbnail ? 90 : null,
        fit: thumbnail ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } on FormatException {
      return const Icon(Icons.broken_image_outlined);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: photos
        .map(
          (photo) => InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: InteractiveViewer(child: image(photo))),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            child: image(photo, thumbnail: true),
          ),
        )
        .toList(),
  );
}
