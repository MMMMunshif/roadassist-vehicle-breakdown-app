part of '../screens.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (signedIn) AuthService().markNotificationsSeen();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: Column(
      children: [
        const _ChatInbox(isProvider: false, preview: true),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: signedIn ? RequestService().watchDriverRequests() : null,
            builder: (context, snapshot) {
              if (!signedIn)
                return const EmptyState(
                  icon: Icons.login_outlined,
                  title: 'Sign in required',
                  message: 'Sign in as a driver to view request notifications.',
                );
              if (snapshot.hasError)
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load updates',
                  message: 'Check your connection and try again.',
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final requests = snapshot.data!.docs;
              if (requests.isEmpty)
                return const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No notifications yet',
                  message:
                      'Request status updates will appear here in real time.',
                );
              return ListView.separated(
                padding: const EdgeInsets.all(RaSpace.xl),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: RaSpace.sm),
                itemBuilder: (context, index) {
                  final data = requests[index].data();
                  final status = data['status'] as String? ?? 'searching';
                  final message = switch (status) {
                    'searching' => 'Searching for an available provider',
                    'accepted' =>
                      '${data['providerName'] ?? 'A provider'} accepted your request',
                    'en_route' => 'Your provider is on the way',
                    'arrived' =>
                      data['completionState'] == 'pending'
                          ? 'Work submitted - confirm completion or report a problem'
                          : 'Your provider has arrived',
                    'completed' => 'Your assistance request is complete',
                    'cancelled' =>
                      data['cancellationReason'] == null
                          ? 'This request was cancelled'
                          : 'Provider unavailable: ${data['cancellationReason']}. Open the request to find another provider',
                    _ => 'Request status updated',
                  };
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(RaSpace.md),
                      leading: IconBadge(
                        status == 'completed'
                            ? Icons.check_circle_outline
                            : Icons.notifications_active_outlined,
                        size: 42,
                      ),
                      title: Text(message, style: RaText.title),
                      subtitle: Text(
                        data['issue'] as String? ?? 'Roadside assistance',
                        style: RaText.bodyMuted,
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
