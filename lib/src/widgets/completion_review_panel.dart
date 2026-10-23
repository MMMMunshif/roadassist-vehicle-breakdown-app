part of '../screens.dart';

const demoPaymentsEnabled = bool.fromEnvironment(
  'DEMO_PAYMENTS',
  defaultValue: false,
);

Future<String?> requestCheckout(
  BuildContext context,
  int amount, {
  bool confirmService = true,
}) {
  String selected = 'cash';
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              confirmService ? 'Accept Bill & Pay' : 'Payment',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Final total: Rs. ${ServiceInvoice.money(amount)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final option in const [
              ('cash', 'Cash', Icons.payments_outlined),
              ('external', 'Bank transfer', Icons.account_balance_outlined),
              if (demoPaymentsEnabled)
                ('demo_card', 'Demo card', Icons.credit_card),
            ])
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                selected: selected == option.$1,
                leading: Icon(option.$3),
                title: Text(option.$2),
                trailing: Icon(
                  selected == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => setSheetState(() => selected = option.$1),
              ),
            const SizedBox(height: 14),
            Text(
              selected == 'demo_card'
                  ? 'DEMO - NO MONEY CHARGED. This simulates a card payment for demonstration only.'
                  : 'Pay the provider directly. Confirm only after paying; the provider will confirm receipt.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, selected),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                selected == 'demo_card'
                    ? (confirmService
                          ? 'Confirm service & simulate payment'
                          : 'Simulate card payment')
                    : (confirmService
                          ? 'Confirm service & paid ${selected == 'cash' ? 'cash' : 'by transfer'}'
                          : 'I paid ${selected == 'cash' ? 'cash' : 'by transfer'}'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
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

  Future<void> questionBill(int total) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question this bill',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('A charge needs correcting'),
              subtitle: const Text('Send the bill back to the provider'),
              onTap: () => Navigator.pop(sheet, 'correct'),
            ),
            ListTile(
              leading: const Icon(Icons.price_change_outlined),
              title: const Text('Ask for a discount'),
              onTap: () => Navigator.pop(sheet, 'discount'),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Report a service problem'),
              onTap: () => Navigator.pop(sheet, 'support'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'discount') {
      await askDiscount(total);
      return;
    }
    if (choice == 'support') {
      push(context, DisputeScreen(requestId: widget.requestId));
      return;
    }
    final reason = await _adminReason(
      context,
      'Which charge needs correcting?',
    );
    if (!mounted || reason == null) return;
    await act(() async {
      await VisitBillingService().send('correct', {
        'requestId': widget.requestId,
        'reason': reason,
      });
    });
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
              data['workflowVersion'] == 3
                  ? 'Final service bill'
                  : 'Final amount agreement',
              style: _providerText(context, size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'LKR ${ServiceInvoice.money(total)}',
              style: _providerText(context, size: 22, weight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (data['workflowVersion'] == 3) FinalBillBreakdown(data: data),
            if (data['workflowVersion'] != 3)
              Text(
                'Approved quote: LKR ${ServiceInvoice.money((data['estimatedCost'] as num?)?.toInt() ?? total)}',
                style: _providerText(context, size: 13, muted: true),
              ),
            if (report.isNotEmpty) ...[
              const Divider(height: 24),
              Text(report, style: _providerText(context, size: 14)),
            ],
            if (data['workflowVersion'] == 3 &&
                !widget.isProvider &&
                pending == null)
              TextButton.icon(
                onPressed: busy ? null : () => questionBill(total),
                icon: const Icon(Icons.help_outline),
                label: const Text('Question this bill'),
              ),
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
            else if (!widget.isProvider &&
                total > 0 &&
                data['workflowVersion'] != 3)
              OutlinedButton.icon(
                onPressed: busy ? null : () => askDiscount(total),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Request a discount'),
              ),
            const SizedBox(height: 8),
            Text(
              widget.isProvider
                  ? 'The driver must agree to the final total before the job closes. Payment is confirmed separately.'
                  : 'Review the charges, then pay the provider directly by cash or bank transfer. Use Question this bill if something needs attention.',
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
