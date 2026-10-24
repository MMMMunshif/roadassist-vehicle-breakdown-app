part of '../screens.dart';

const demoPaymentsEnabled = bool.fromEnvironment(
  'DEMO_PAYMENTS',
  defaultValue: false,
);

/// A reported manual payment is not a receipt until the provider confirms it.
bool needsProviderReceiptConfirmation(Map<String, dynamic> data) =>
    data['status'] == 'completed' &&
    data['driverReportedPayment'] == true &&
    data['providerConfirmedPayment'] != true &&
    data['paymentMethod'] != 'demo_card' &&
    !(data['demoPayment'] is Map &&
        data['demoPayment']['status'] == 'simulated');

Future<String?> requestCheckout(
  BuildContext context,
  int amount, {
  bool confirmService = true,
  bool showDemoCard = demoPaymentsEnabled,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PaymentWallet(
      amount: amount,
      confirmService: confirmService,
      showDemoCard: showDemoCard,
    ),
  ),
);

class _PaymentWallet extends StatefulWidget {
  const _PaymentWallet({
    required this.amount,
    required this.confirmService,
    required this.showDemoCard,
  });
  final int amount;
  final bool confirmService;
  final bool showDemoCard;
  @override
  State<_PaymentWallet> createState() => _PaymentWalletState();
}

class _PaymentWalletState extends State<_PaymentWallet> {
  String? method;

  Future<void> confirm() async {
    if (method == 'cash') {
      Navigator.pop(context, 'cash');
      return;
    }
    if (method != 'card') return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Card checkout · Demo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SANDBOX / NO REAL CHARGE'),
            const SizedBox(height: 16),
            Text(
              'LKR ${ServiceInvoice.money(widget.amount)}.00',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Live card checkout requires a payment gateway and merchant approval. '
              'No card details or money are collected. Your bill and payment status stay unchanged.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduced =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    final duration = Duration(milliseconds: reduced ? 0 : 350);
    final card = method == 'card';
    return RaScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/roadassist_mark.png',
                        width: 32,
                        height: 36,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'RoadAssist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close payment',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'FINAL SERVICE BILL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LKR ${ServiceInvoice.money(widget.amount)}.00',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Choose how to pay your provider.'),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) => Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colors.outline.withValues(alpha: .25),
                              ),
                            ),
                            child: Stack(
                              children: [
                                AnimatedAlign(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  alignment: card
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: AnimatedOpacity(
                                    duration: duration,
                                    opacity: method == null ? 0 : 1,
                                    child: Container(
                                      width:
                                          (constraints.maxWidth - 10) /
                                          (widget.showDemoCard ? 2 : 1),
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: .18,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (final option in [
                                      ('cash', 'Cash', Icons.payments_outlined),
                                      if (widget.showDemoCard)
                                        (
                                          'card',
                                          'Pay by card',
                                          Icons.credit_card_rounded,
                                        ),
                                    ])
                                      Expanded(
                                        child: Semantics(
                                          selected: method == option.$1,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(0, 64),
                                            ),
                                            onPressed: () => setState(
                                              () => method = option.$1,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(option.$3, size: 20),
                                                Text(
                                                  option.$2,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: duration,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: .94,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: SizedBox(
                            key: ValueKey(method),
                            height: 170,
                            child: Center(
                              child: Transform.rotate(
                                angle: reduced ? 0 : -.07,
                                child: Container(
                                  width: 240,
                                  height: 138,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.primary.withValues(alpha: .75),
                                        colors.primary.withValues(alpha: .25),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: .4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        card
                                            ? Icons.credit_card
                                            : Icons.payments_outlined,
                                        size: 38,
                                      ),
                                      const Spacer(),
                                      Text(
                                        method == null
                                            ? 'Choose your method'
                                            : card
                                            ? '••••  ••••  ••••'
                                            : 'Pay your provider directly',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (card)
                                        const Text(
                                          'DEMO · NO REAL CHARGE',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          method == null
                              ? 'Your payment. Your choice.'
                              : card
                              ? 'Secure card checkout · Demo'
                              : 'A simple handover.',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          method == null
                              ? (widget.showDemoCard
                                    ? 'Select cash or explore the card checkout demo. Your total stays the same.'
                                    : 'Choose cash, then confirm only after paying your provider.')
                              : card
                              ? 'Demo only. No real card details or money are collected.'
                              : 'Hand the cash to your provider. Confirm below only after paying.',
                        ),
                        const SizedBox(height: 28),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                card
                                    ? 'Live card payments will require verified gateway confirmation.'
                                    : 'Your provider confirms receipt after you report cash payment.',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.confirmService) ...[
                        Text(
                          card
                              ? 'The demo does not approve your bill.'
                              : 'Confirming cash payment also approves this final bill.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                      ],
                      FilledButton.icon(
                        onPressed: method == null ? null : confirm,
                        icon: Icon(
                          card ? Icons.credit_card : Icons.arrow_forward,
                        ),
                        label: Text(
                          method == null
                              ? 'Choose payment method'
                              : card
                              ? 'Try demo checkout'
                              : 'Confirm cash paid',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
                  : 'Review the charges, then choose payment. Cash receipt is confirmed by your provider. Use Question this bill if something needs attention.',
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
