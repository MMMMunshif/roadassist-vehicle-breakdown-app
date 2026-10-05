part of '../screens.dart';

class ProviderNotificationsScreen extends StatelessWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Assistance Requests')),
    body: Column(
      children: [
        const _ChatInbox(isProvider: true, preview: true),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: signedIn ? AuthService().watchCurrentProfile() : null,
            builder: (context, profileSnapshot) {
              final savedServices =
                  profileSnapshot.data?.data()?['services'] as List<dynamic>?;
              final services = savedServices == null || savedServices.isEmpty
                  ? const [
                      'Vehicle Towing',
                      'Battery Jumpstart',
                      'Flat Tyre',
                      'General Mechanic',
                    ]
                  : savedServices.whereType<String>().toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: signedIn ? RequestService().watchOpenRequests() : null,
                builder: (context, snapshot) {
                  if (!signedIn) {
                    return const EmptyState(
                      icon: Icons.login_outlined,
                      title: 'Sign in required',
                      message: 'Sign in as a provider to view new requests.',
                    );
                  }
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load requests',
                      message: 'Check your connection and try again.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final userId = FirebaseAuth.instance.currentUser!.uid;
                  final requests = snapshot.data!.docs.where((request) {
                    return _requestMatchesProvider(
                      request.data(),
                      userId,
                      services: services,
                    );
                  }).toList();
                  if (requests.isEmpty) {
                    return const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No new requests',
                      message:
                          'Matching driver requests will appear here in real time.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(RaSpace.xl),
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: RaSpace.md),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final data = request.data();
                      final driver = data['driverName'] as String? ?? 'Driver';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(RaSpace.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ProfileInitials(name: driver, radius: 21),
                                  const SizedBox(width: RaSpace.md),
                                  Expanded(
                                    child: Text(driver, style: RaText.title),
                                  ),
                                  const StatusPill(
                                    label: 'New',
                                    tone: RaTone.warning,
                                  ),
                                ],
                              ),
                              const SizedBox(height: RaSpace.md),
                              SummaryRow(
                                'Service',
                                data['issue'] as String? ??
                                    'Roadside assistance',
                              ),
                              SummaryRow(
                                'Location',
                                data['locationLabel'] as String? ??
                                    'Pinned location',
                              ),
                              SummaryRow(
                                'Pricing',
                                data['workflowVersion'] == 2
                                    ? 'Your quote required'
                                    : 'Rs. ${data['estimatedCost'] ?? 0}',
                                strong: true,
                              ),
                              const SizedBox(height: RaSpace.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await RequestService().rejectRequest(
                                          request.id,
                                        );
                                      },
                                      child: const Text('Dismiss'),
                                    ),
                                  ),
                                  const SizedBox(width: RaSpace.sm),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        try {
                                          final quote =
                                              await requestProviderQuote(
                                                context,
                                                data,
                                              );
                                          if (quote == null ||
                                              !context.mounted) {
                                            return;
                                          }
                                          await RequestService().acceptRequest(
                                            request.id,
                                            serviceFee:
                                                quote['serviceFee'] as int,
                                            travelFee:
                                                quote['travelFee'] as int,
                                            extraFee: quote['extraFee'] as int,
                                            providerDistanceKm:
                                                quote['providerDistanceKm']
                                                    as double,
                                            quoteNotes:
                                                quote['quoteNotes'] as String,
                                            quoteType:
                                                quote['quoteType'] as String,
                                          );
                                          if (!context.mounted) return;
                                          if (data['workflowVersion'] == 2) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Offer sent. Waiting for driver selection.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final acceptedData =
                                              Map<String, dynamic>.from(data)
                                                ..addAll(quote)
                                                ..['dispatchFee'] =
                                                    quote['travelFee']
                                                ..['estimatedCost'] =
                                                    (quote['serviceFee']
                                                        as int) +
                                                    (quote['travelFee']
                                                        as int) +
                                                    (quote['extraFee'] as int)
                                                ..['status'] = 'accepted';
                                          replace(
                                            context,
                                            ProviderActiveJobScreen(
                                              requestId: request.id,
                                              requestData: acceptedData,
                                            ),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          final activeJob = error
                                              .toString()
                                              .contains(
                                                'Complete your active job',
                                              );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                activeJob
                                                    ? 'Complete your active job before accepting another request.'
                                                    : 'This request is no longer available.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Review & Quote'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
