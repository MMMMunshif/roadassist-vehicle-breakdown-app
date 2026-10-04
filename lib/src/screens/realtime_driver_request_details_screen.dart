part of '../screens.dart';

class RealtimeDriverRequestDetailsScreen extends StatelessWidget {
  const RealtimeDriverRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });
  final String requestId;
  final Map<String, dynamic> data;

  void showReceipt(BuildContext context) =>
      push(context, InvoiceScreen(requestId: requestId));

  Future<void> rateService(BuildContext context) async {
    var selectedRating = (data['driverRating'] as num?)?.toInt() ?? 0;
    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rate Your Service', style: RaText.headline),
                const SizedBox(height: RaSpace.xs),
                const Text(
                  'How was your roadside assistance experience?',
                  style: RaText.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RaSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () =>
                          setSheetState(() => selectedRating = index + 1),
                      icon: Icon(
                        index < selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: raGold,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedRating == 0
                        ? null
                        : () => Navigator.pop(sheetContext, selectedRating),
                    child: const Text('Submit Rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (rating == null || !context.mounted) return;
    try {
      await RequestService().submitDriverRating(requestId, rating);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your $rating-star rating.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save rating. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final provider = data['providerName'] as String? ?? 'Not assigned';
    final providerPhone = data['providerPhone'] as String? ?? '';
    final status = (data['status'] as String? ?? 'searching').replaceAll(
      '_',
      ' ',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          SizedBox(
            height: 210,
            child: MapMock(position: LatLng(latitude, longitude)),
          ),
          const SizedBox(height: RaSpace.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  SummaryRow('Request ID', requestId),
                  SummaryRow('Status', status),
                  SummaryRow(
                    'Assistance Type',
                    data['issue'] as String? ?? 'Roadside assistance',
                  ),
                  SummaryRow('Provider', provider),
                  SummaryRow(
                    'Vehicle',
                    data['modelYear'] as String? ??
                        data['vehicleType'] as String? ??
                        'Not provided',
                  ),
                  SummaryRow(
                    'Registration',
                    data['registration'] as String? ?? 'Not provided',
                  ),
                  SummaryRow(
                    'Location',
                    data['locationLabel'] as String? ?? 'Pinned location',
                  ),
                  SummaryRow(
                    'Description',
                    data['description'] as String? ?? 'No description',
                  ),
                  const Divider(),
                  SummaryRow(
                    'Service Charge',
                    'Rs. ${data['serviceFee'] ?? 0}',
                  ),
                  SummaryRow(
                    'Travel / Distance Charge',
                    'Rs. ${data['dispatchFee'] ?? 0}',
                  ),
                  SummaryRow('Extra Charge', 'Rs. ${data['extraFee'] ?? 0}'),
                  if ((data['providerDistanceKm'] as num?) != null)
                    SummaryRow(
                      'Provider Distance',
                      '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
                    ),
                  if ((data['quoteNotes'] as String? ?? '').isNotEmpty)
                    SummaryRow('Quote Notes', data['quoteNotes'] as String),
                  const Divider(),
                  SummaryRow(
                    data['finalCost'] == null ? 'Quoted Total' : 'Final Total',
                    'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: providerPhone.isEmpty
                      ? null
                      : () => showCallPrompt(
                          context,
                          name: provider,
                          number: providerPhone,
                        ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call Provider'),
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: data['providerId'] == null
                      ? null
                      : () => push(
                          context,
                          ChatScreen(
                            requestId: requestId,
                            peerName: provider,
                            peerPhone: providerPhone,
                          ),
                        ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Chat'),
                ),
              ),
            ],
          ),
          if (data['status'] == 'completed') ...[
            const SizedBox(height: RaSpace.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showReceipt(context),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Receipt'),
                  ),
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => rateService(context),
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(
                      data['driverRating'] == null
                          ? 'Rate Service'
                          : 'Update Rating',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
