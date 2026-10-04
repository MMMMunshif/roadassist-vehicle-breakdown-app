part of '../screens.dart';

class QuoteOffers extends StatefulWidget {
  const QuoteOffers({super.key, required this.requestId});
  final String requestId;
  @override
  State<QuoteOffers> createState() => _QuoteOffersState();
}

class _QuoteOffersState extends State<QuoteOffers> {
  bool selecting = false;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> offers;
  @override
  void initState() {
    super.initState();
    offers = RequestService().watchQuotes(widget.requestId);
  }

  Future<void> choose(String id, Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Approve this offer?'),
        content: Text(
          '${offer['providerName']}\n${offer['quoteType'] == 'inspection' ? 'Inspection and visit only. Repair is not included.\n' : ''}Total: Rs. ${offer['total']}\n${offer['notes']}\n\nOnly the listed work is included. Additional work requires an approved revision.',
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
      await RequestService().selectQuote(widget.requestId, id);
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
      if (snapshot.hasError)
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Could not load offers. Check your connection.'),
          ),
        );
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
          const Text('Provider offers', style: RaText.headline),
          const SizedBox(height: 8),
          Text(
            quotes.isEmpty
                ? 'Providers are reviewing your vehicle and request. No price has been agreed yet.'
                : 'Direct service and inspection offers are grouped separately, then sorted by price. Compare what each offer includes.',
          ),
          for (final quote in quotes)
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
                    Text(quote.data()['notes'] as String),
                    FilledButton(
                      onPressed: selecting
                          ? null
                          : () => choose(quote.id, quote.data()),
                      child: Text(selecting ? 'Selecting…' : 'Review & Select'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
