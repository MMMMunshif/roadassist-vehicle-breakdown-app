part of '../../screens.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request History')),
    body: !signedIn
        ? const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to view request history.',
          )
        : Column(
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
                  stream: RequestService().watchDriverRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load history',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final requests = snapshot.data!.docs.where((request) {
                      final status = request.data()['status'] as String? ?? '';
                      if (filter == 1) return status == 'completed';
                      if (filter == 2) return status == 'cancelled';
                      return true;
                    }).toList();
                    if (requests.isEmpty) {
                      return EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: filter == 0
                            ? 'No requests yet'
                            : 'No matching requests',
                        message: filter == 0
                            ? 'Your assistance requests will appear here.'
                            : 'There are no requests in this category.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        RaSpace.xl,
                        0,
                        RaSpace.xl,
                        RaSpace.xl,
                      ),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RaSpace.md),
                      itemBuilder: (context, index) => _DriverHistoryCard(
                        requestId: requests[index].id,
                        data: requests[index].data(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}
