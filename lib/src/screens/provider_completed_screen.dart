part of '../screens.dart';

class ProviderCompletedScreen extends StatelessWidget {
  const ProviderCompletedScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });
  final String requestId;
  final Map<String, dynamic> requestData;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.xxl),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: raSuccessPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 50, color: raSuccess),
            ),
            const SizedBox(height: RaSpace.xl),
            const Text(
              'Assistance Completed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: raNavy,
              ),
            ),
            const SizedBox(height: RaSpace.xs),
            Text(
              'Request $requestId has been marked as completed.',
              textAlign: TextAlign.center,
              style: RaText.bodyMuted,
            ),
            const SizedBox(height: RaSpace.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(RaSpace.lg),
                child: Column(
                  children: [
                    SummaryRow(
                      'Service',
                      requestData['issue'] as String? ?? 'Roadside assistance',
                    ),
                    SummaryRow(
                      'Driver',
                      requestData['driverName'] as String? ?? 'Driver',
                    ),
                    SummaryRow(
                      'Vehicle',
                      [requestData['modelYear'], requestData['registration']]
                              .whereType<String>()
                              .where((value) => value.trim().isNotEmpty)
                              .join(' - ')
                              .isEmpty
                          ? 'Not provided'
                          : [
                                  requestData['modelYear'],
                                  requestData['registration'],
                                ]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' - '),
                    ),
                    SummaryRow(
                      'Location',
                      requestData['locationLabel'] as String? ??
                          'Pinned location',
                    ),
                    if ((requestData['serviceNotes'] as String? ?? '')
                        .trim()
                        .isNotEmpty)
                      SummaryRow(
                        'Service Notes',
                        requestData['serviceNotes'] as String,
                      ),
                    const Divider(),
                    SummaryRow(
                      'Final Cost',
                      'Rs. ${requestData['finalCost'] ?? requestData['estimatedCost'] ?? 0}',
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => replace(context, const ProviderShell()),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// SHARED — STATUS & TIMELINE
// ============================================================
