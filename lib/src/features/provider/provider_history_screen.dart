part of '../../screens.dart';

class ProviderHistoryScreen extends StatefulWidget {
  const ProviderHistoryScreen({super.key});
  @override
  State<ProviderHistoryScreen> createState() => _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState extends State<ProviderHistoryScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider Request History')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            RaSpace.xl,
            RaSpace.xl,
            RaSpace.md,
          ),
          child: FilterRow(
            selected: filter,
            onSelected: (value) => setState(() => filter = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService().watchProviderRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load history',
                  message: 'Check your connection and try again.',
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final jobs = snapshot.data!.docs.where((job) {
                final status = job.data()['status'] as String? ?? '';
                if (filter == 1) return status == 'completed';
                if (filter == 2)
                  return status == 'cancelled' || status == 'rejected';
                return status == 'completed' ||
                    status == 'cancelled' ||
                    status == 'rejected';
              }).toList();
              if (jobs.isEmpty)
                return EmptyState(
                  icon: Icons.history_outlined,
                  title: filter == 0
                      ? 'No job history'
                      : filter == 1
                      ? 'No completed jobs'
                      : 'No cancelled jobs',
                  message:
                      'Matching provider jobs will appear here automatically.',
                );
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.xl,
                  RaSpace.sm,
                  RaSpace.xl,
                  RaSpace.xl,
                ),
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: RaSpace.md),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final data = job.data();
                  final created = (data['createdAt'] as Timestamp?)?.toDate();
                  final date = created == null
                      ? 'Date unavailable'
                      : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                  final vehicle = [data['modelYear'], data['registration']]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' - ');
                  return ProviderJobCard(
                    driver: data['driverName'] as String? ?? 'Driver',
                    vehicle: vehicle.isEmpty
                        ? data['vehicleType'] as String? ?? 'Vehicle'
                        : vehicle,
                    service: data['issue'] as String? ?? 'Roadside assistance',
                    date: date,
                    location:
                        data['locationLabel'] as String? ?? 'Pinned location',
                    cost:
                        'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    completed: data['status'] == 'completed',
                    onViewDetails: () => push(
                      context,
                      ProviderRequestDetailsScreen(
                        requestId: job.id,
                        data: data,
                      ),
                    ),
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
