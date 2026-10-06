part of '../../screens.dart';

class DriverRequestDetailsScreen extends StatelessWidget {
  const DriverRequestDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request Details')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.md),
          decoration: BoxDecoration(
            color: raSuccessPale,
            borderRadius: BorderRadius.circular(RaRadius.sm),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: raSuccess),
              SizedBox(width: RaSpace.sm),
              Expanded(
                child: Text(
                  'Service completed successfully',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: raSuccess,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.md),
        const InfoStrip(
          icon: Icons.receipt_long_outlined,
          title: 'Request RA-8829-XJ',
          value: '25 Aug 2026 - 02:30 PM',
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              children: const [
                SummaryRow('Assistance Type', 'Flat Tyre Repair'),
                SummaryRow('Vehicle', 'Toyota Premio - WP CAS 8822'),
                SummaryRow('Pickup Location', 'Galle Road, Colombo 03'),
                SummaryRow('Provider', 'Kasun Jayawardena'),
                Divider(),
                SummaryRow('Service Fee', 'Rs. 1,500'),
                SummaryRow('Distance Charge', 'Rs. 850'),
                SummaryRow('Emergency Charge', 'Rs. 500'),
                Divider(),
                SummaryRow('Total Paid', 'Rs. 2,850', strong: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const Text('Request Timeline', style: RaText.headline),
        const SizedBox(height: RaSpace.md),
        const DetailTimeline(),
        const SizedBox(height: RaSpace.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    icon: const Icon(Icons.receipt_long, color: raBlue),
                    title: const Text('Receipt RA-8829-XJ'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SummaryRow('Service', 'Flat Tyre Repair'),
                        SummaryRow('Provider', 'Kasun Jayawardena'),
                        SummaryRow('Date', '25 Aug 2026 - 02:30 PM'),
                        Divider(),
                        SummaryRow('Total Paid', 'Rs. 2,850', strong: true),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Receipt'),
              ),
            ),
            const SizedBox(width: RaSpace.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) {
                    var rating = 0;
                    return StatefulBuilder(
                      builder: (context, setSheetState) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Rate your service',
                                style: RaText.headline,
                              ),
                              const SizedBox(height: RaSpace.sm),
                              const Text(
                                'How was your roadside assistance?',
                                style: RaText.bodyMuted,
                              ),
                              const SizedBox(height: RaSpace.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (index) => IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                    ),
                                    onPressed: () =>
                                        setSheetState(() => rating = index + 1),
                                    icon: Icon(
                                      index < rating
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: raGold,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: RaSpace.md),
                              FilledButton(
                                onPressed: rating == 0
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Thank you for your $rating-star rating.',
                                            ),
                                          ),
                                        );
                                        Navigator.pop(sheetContext);
                                      },
                                child: const Text('Submit Rating'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate Service'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
