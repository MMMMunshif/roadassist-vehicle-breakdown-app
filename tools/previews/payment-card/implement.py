from pathlib import Path
p=Path('lib/src/widgets/completion_review_panel.dart');s=p.read_text();a=s.index('Future<String?> requestCheckout(');b=s.index('class CompletionReviewPanel',a)
s=s[:a]+'''Future<String?> requestCheckout(
  BuildContext context,
  int amount, {
  bool confirmService = true,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PaymentWallet(amount: amount, confirmService: confirmService),
  ),
);

class _PaymentWallet extends StatefulWidget {
  const _PaymentWallet({required this.amount, required this.confirmService});
  final int amount;
  final bool confirmService;
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
            Text('LKR ${ServiceInvoice.money(widget.amount)}.00',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('Live card checkout requires a payment gateway and merchant approval. '
                'No card details or money are collected. Your bill and payment status stay unchanged.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Back to payment'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduced = MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    final duration = Duration(milliseconds: reduced ? 0 : 350);
    final card = method == 'card';
    return RaScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                child: Row(children: [
                  Image.asset('assets/images/roadassist_mark.png', width: 32, height: 36),
                  const SizedBox(width: 8),
                  Text('RoadAssist', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(tooltip: 'Close payment', onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('FINAL SERVICE BILL', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text('LKR ${ServiceInvoice.money(widget.amount)}.00',
                    style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Choose how to pay your provider.'),
                  const SizedBox(height: 28),
                  LayoutBuilder(builder: (context, constraints) => Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outline.withValues(alpha: .25)),
                    ),
                    child: Stack(children: [
                      AnimatedAlign(
                        duration: duration, curve: Curves.easeOutCubic,
                        alignment: card ? Alignment.centerRight : Alignment.centerLeft,
                        child: AnimatedOpacity(duration: duration, opacity: method == null ? 0 : 1,
                          child: Container(width: (constraints.maxWidth - 10) / 2, height: 64,
                            decoration: BoxDecoration(color: colors.primary.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(14)))),
                      ),
                      Row(children: [
                        for (final option in const [('cash', 'Cash', Icons.payments_outlined),
                            ('card', 'Pay by card', Icons.credit_card_rounded)])
                          Expanded(child: Semantics(selected: method == option.$1,
                            child: TextButton(
                              style: TextButton.styleFrom(minimumSize: const Size(0, 64)),
                              onPressed: () => setState(() => method = option.$1),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(option.$3, size: 20),
                                Text(option.$2, textAlign: TextAlign.center),
                              ]),
                            ))),
                      ]),
                    ]),
                  )),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(duration: duration,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation,
                      child: ScaleTransition(scale: Tween<double>(begin: .94, end: 1).animate(animation), child: child)),
                    child: SizedBox(key: ValueKey(method), height: 170,
                      child: Center(child: Transform.rotate(angle: reduced ? 0 : -.07,
                        child: Container(width: 240, height: 138,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [colors.primary.withValues(alpha: .75), colors.primary.withValues(alpha: .25)]),
                            border: Border.all(color: colors.primary.withValues(alpha: .4)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(card ? Icons.credit_card : Icons.payments_outlined, size: 38),
                            const Spacer(),
                            Text(method == null ? 'Choose your method' : card ? '••••  ••••  ••••' : 'Pay your provider directly'),
                            if (card) const Text('DEMO · NO REAL CHARGE', style: TextStyle(fontSize: 10)),
                          ]),
                        )),
                      )),
                  ),
                  const SizedBox(height: 20),
                  Text(method == null ? 'Your payment. Your choice.' : card ? 'Secure card checkout · Demo' : 'A simple handover.',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(method == null ? 'Select cash or explore the card checkout demo. Your total stays the same.'
                      : card ? 'Demo only. No real card details or money are collected.'
                      : 'Hand the cash to your provider. Confirm below only after paying.'),
                  const SizedBox(height: 28),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 18), const SizedBox(width: 10),
                    Expanded(child: Text(card
                        ? 'Live card payments will require verified gateway confirmation.'
                        : 'Your provider confirms receipt after you report cash payment.')),
                  ]),
                ]),
              )),
              Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (widget.confirmService) ...[
                    Text(card ? 'The demo does not approve your bill.' : 'Confirming cash payment also approves this final bill.',
                      textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(onPressed: method == null ? null : confirm,
                    icon: Icon(card ? Icons.credit_card : Icons.arrow_forward),
                    label: Text(method == null ? 'Choose payment method' : card ? 'Try demo checkout' : 'Confirm cash paid'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

'''+s[b:];p.write_text(s)
