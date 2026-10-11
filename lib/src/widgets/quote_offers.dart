part of '../screens.dart';

class QuoteOffers extends StatefulWidget {
  const QuoteOffers({
    super.key,
    required this.requestId,
    this.providerView = false,
  });
  final bool providerView;
  final String requestId;
  @override
  State<QuoteOffers> createState() => _QuoteOffersState();
}

class _QuoteOffersState extends State<QuoteOffers> {
  bool selecting = false;
  late Stream<QuerySnapshot<Map<String, dynamic>>> offers;
  @override
  void initState() {
    super.initState();
    offers = RequestService().watchQuotes(
      widget.requestId,
      ownQuoteOnly: widget.providerView,
    );
  }

  Future<void> choose(String id, Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Approve this offer?'),
        content: Text(
          '${offer['providerName']}\n${offer['quoteType'] == 'inspection' ? 'Inspection and visit only. Repair is not included.\n' : ''}Total: Rs. ${offer['total']}\nIncluded work / exclusions: ${offer['notes']}\n${_warrantyLabel(offer)}\n\nOnly the listed work is included. Additional work requires an approved revision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Approve & Select'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => selecting = true);
    try {
      await RequestService().selectQuote(
        widget.requestId,
        id,
        expectedOffer: offer,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: offers,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _workflowError(
                    snapshot.error!,
                    'Could not load offers. Please try again.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    offers = RequestService().watchQuotes(
                      widget.requestId,
                      ownQuoteOnly: widget.providerView,
                    );
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final quotes = snapshot.data!.docs.toList()
        ..sort((a, b) {
          final type = (a.data()['quoteType'] as String? ?? 'direct').compareTo(
            b.data()['quoteType'] as String? ?? 'direct',
          );
          return type != 0
              ? type
              : (a.data()['total'] as num).compareTo(b.data()['total'] as num);
        });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.providerView ? 'Your quote' : 'Provider offers',
            style: RaText.headline,
          ),
          const SizedBox(height: 8),
          Text(
            widget.providerView
                ? (quotes.isEmpty
                      ? 'You have not sent a quote yet. Use Review & Quote to send your offer.'
                      : 'Your submitted price and included work are shown below. The driver reviews and selects offers.')
                : quotes.isEmpty
                ? 'Providers are reviewing your vehicle and request. No price has been agreed yet.'
                : 'Direct service and inspection offers are grouped separately, then sorted by price. Compare what each offer includes.',
          ),
          for (final type in ['direct', 'inspection']) ...[
            if (quotes.any((q) => (q.data()['quoteType'] ?? 'direct') == type))
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  type == 'direct'
                      ? 'Repair / service offers - lowest total first'
                      : 'Visit / inspection offers - repair costs extra',
                  style: RaText.title,
                ),
              ),
            for (final quote in quotes.where(
              (q) => (q.data()['quoteType'] ?? 'direct') == type,
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        quote.data()['providerName'] as String,
                        style: RaText.title,
                      ),
                      Text(
                        quote.data()['quoteType'] == 'inspection'
                            ? 'Inspection only — repair is not included'
                            : 'Direct service offer',
                      ),
                      SummaryRow(
                        'Service / labour',
                        'Rs. ${quote.data()['serviceFee']}',
                      ),
                      SummaryRow('Travel', 'Rs. ${quote.data()['travelFee']}'),
                      SummaryRow(
                        'Other stated charges',
                        'Rs. ${quote.data()['extraFee']}',
                      ),
                      SummaryRow(
                        'Quoted total',
                        'Rs. ${quote.data()['total']}',
                        strong: true,
                      ),
                      if (!widget.providerView &&
                          quote.id ==
                              quotes
                                  .firstWhere(
                                    (q) =>
                                        (q.data()['quoteType'] ?? 'direct') ==
                                        type,
                                  )
                                  .id)
                        const Text('Lowest quoted price in this category'),
                      const SizedBox(height: 8),
                      const Text(
                        'Included work, parts and exclusions',
                        style: RaText.label,
                      ),
                      Text(quote.data()['notes'] as String),
                      Text(_warrantyLabel(quote.data())),
                      const SizedBox(height: 8),
                      if (!widget.providerView)
                        FilledButton(
                          onPressed: selecting
                              ? null
                              : () => choose(quote.id, quote.data()),
                          child: Text(
                            selecting ? 'Selecting…' : 'Review & Select',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
