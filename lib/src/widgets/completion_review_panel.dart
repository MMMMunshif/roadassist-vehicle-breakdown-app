part of '../screens.dart';

Future<CompletionReport?> requestCompletionReport(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  final saved = data['completionReport'] is Map
      ? data['completionReport'] as Map
      : const {};
  final fields = ['problem', 'repairs', 'parts', 'advice'];
  final controllers = {
    for (final field in fields)
      field: TextEditingController(text: saved[field] as String? ?? ''),
  };
  final form = GlobalKey<FormState>();
  final result = await showDialog<CompletionReport>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Completed repair report'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'These details will be shown to the driver and included in the invoice.',
                ),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextFormField(
                      controller: controllers[field],
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: switch (field) {
                          'problem' => 'Exact vehicle problem',
                          'repairs' => 'Repair / work performed',
                          'parts' => 'Parts replaced, quantity and details',
                          _ => 'Advice / follow-up (optional)',
                        },
                        helperText: field == 'parts'
                            ? 'Enter No parts replaced when applicable.'
                            : null,
                      ),
                      validator: (value) {
                        final length = (value ?? '').trim().length;
                        if (field == 'advice') return null;
                        if (length < (field == 'parts' ? 1 : 10)) {
                          return field == 'parts'
                              ? 'List parts or enter No parts replaced.'
                              : 'Enter at least 10 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(
                dialogContext,
                CompletionReport(
                  problem: controllers['problem']!.text,
                  repairs: controllers['repairs']!.text,
                  parts: controllers['parts']!.text,
                  advice: controllers['advice']!.text,
                ),
              );
            }
          },
          child: const Text('Review final amount'),
        ),
      ],
    ),
  );
  // Wait for the dialog route to finish its reverse animation before disposal.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}

class CompletionReviewPanel extends StatefulWidget {
  const CompletionReviewPanel({
    super.key,
    required this.requestId,
    this.isProvider = false,
  });
  final String requestId;
  final bool isProvider;
  @override
  State<CompletionReviewPanel> createState() => _CompletionReviewPanelState();
}

class _CompletionReviewPanelState extends State<CompletionReviewPanel> {
  late final request = RequestService().watchRequest(widget.requestId);
  bool busy = false;
  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> askDiscount(int current) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request a discount'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Proposed final total: LKR ${ServiceInvoice.money(current)}. The provider must agree to your requested amount.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Requested final total (LKR)',
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n < 0 || n >= current
                        ? 'Enter an amount below the proposed total.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: reason,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (value) => (value ?? '').trim().length < 10
                      ? 'Enter at least 10 characters.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, (
                  int.parse(amount.text),
                  reason.text,
                ));
              }
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
    reason.dispose();
    if (result != null && mounted) {
      await act(
        () => RequestService().requestCompletionDiscount(
          widget.requestId,
          result.$1,
          result.$2,
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: request,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const InlineMessage(
          icon: Icons.cloud_off_outlined,
          text: 'Unable to load the final amount. Reconnect before confirming.',
        );
      }
      final data = snapshot.data?.data();
      if (data == null) return const LinearProgressIndicator();
      final total = (data['finalCost'] as num?)?.toInt();
      if (data['completionState'] != 'pending' || total == null) {
        return const SizedBox.shrink();
      }
      final pending = data['pendingDiscountId'] as String?;
      final report = CompletionReport.description(data);
      return RaProviderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Final amount agreement',
              style: _providerText(context, size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'LKR ${ServiceInvoice.money(total)}',
              style: _providerText(context, size: 22, weight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Approved quote: LKR ${ServiceInvoice.money((data['estimatedCost'] as num?)?.toInt() ?? total)}',
              style: _providerText(context, size: 13, muted: true),
            ),
            if (report.isNotEmpty) ...[
              const Divider(height: 24),
              Text(report, style: _providerText(context, size: 14)),
            ],
            const SizedBox(height: 12),
            if (pending != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .doc(widget.requestId)
                    .collection('completionDiscounts')
                    .doc(pending)
                    .snapshots(),
                builder: (context, offerSnapshot) {
                  if (offerSnapshot.hasError) {
                    return const Text(
                      'Unable to load the discount request. Reconnect to review it.',
                    );
                  }
                  final offer = offerSnapshot.data?.data();
                  if (offer == null) return const LinearProgressIndicator();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Requested total: LKR ${ServiceInvoice.money((offer['requestedTotal'] as num).toInt())}',
                        style: _providerText(context, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(offer['reason'] as String),
                      if (widget.isProvider) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  () => RequestService()
                                      .respondCompletionDiscount(
                                        widget.requestId,
                                        pending,
                                        accept: true,
                                      ),
                                ),
                          child: const Text('Accept discount'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  () => RequestService()
                                      .respondCompletionDiscount(
                                        widget.requestId,
                                        pending,
                                        accept: false,
                                      ),
                                ),
                          child: const Text('Decline discount'),
                        ),
                      ] else
                        const Text(
                          'Waiting for provider response. Completion stays open.',
                        ),
                    ],
                  );
                },
              )
            else if (!widget.isProvider && total > 0)
              OutlinedButton.icon(
                onPressed: busy ? null : () => askDiscount(total),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Request a discount'),
              ),
            const SizedBox(height: 8),
            Text(
              widget.isProvider
                  ? 'The driver must agree to the final total before the job closes. Payment is confirmed separately.'
                  : 'Completing this job confirms the work and final amount. It does not record payment. If you disagree, request a discount or report an issue.',
              style: _providerText(context, size: 13, muted: true),
            ),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .doc(widget.requestId)
                  .collection('completionDiscounts')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, history) {
                if (history.hasError) {
                  return const Text(
                    'Price agreement history is temporarily unavailable.',
                  );
                }
                final docs = history.data?.docs ?? [];
                if (docs.isEmpty) return const SizedBox.shrink();
                return ExpansionTile(
                  title: const Text('Discount history'),
                  children: [
                    for (final doc in docs)
                      ListTile(
                        title: Text(
                          'LKR ${doc.data()['previousTotal']} ? LKR ${doc.data()['requestedTotal']} ? ${doc.data()['status']}',
                        ),
                        subtitle: Text(doc.data()['reason'] as String),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
