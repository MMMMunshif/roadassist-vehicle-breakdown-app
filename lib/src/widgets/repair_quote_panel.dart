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
                        Text(offer['diagnosisAndWork'] as String),
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
                                          'Authorize the described work for Rs. ${offer['total']} in total.',
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
                    data['approvedRepairId'] == null
                        ? 'Submit Repair Quote'
                        : 'Propose Additional Work',
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
