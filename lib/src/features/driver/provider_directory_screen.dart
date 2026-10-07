part of '../../screens.dart';

class ProviderDirectoryScreen extends StatefulWidget {
  const ProviderDirectoryScreen({super.key});
  @override
  State<ProviderDirectoryScreen> createState() =>
      _ProviderDirectoryScreenState();
}

class _ProviderDirectoryScreenState extends State<ProviderDirectoryScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) => !signedIn
      ? Scaffold(
          appBar: AppBar(title: const Text('Nearby Providers')),
          body: const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to search online providers.',
          ),
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Nearby Providers')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(RaSpace.xl),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search provider by name',
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AuthService().watchOnlineProviders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load providers',
                        message: 'Check your connection and try again.',
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final providers = snapshot.data!.docs.where((doc) {
                      final name = (doc.data()['displayName'] as String? ?? '')
                          .toLowerCase();
                      return _providerHasCurrentVerification(doc.data()) &&
                          name.contains(query);
                    }).toList();
                    if (providers.isEmpty)
                      return EmptyState(
                        icon: Icons.person_search_outlined,
                        title: query.isEmpty
                            ? 'No providers online'
                            : 'No matching provider',
                        message: query.isEmpty
                            ? 'Online providers will appear automatically.'
                            : 'Try a different provider name.',
                      );
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        RaSpace.xl,
                        0,
                        RaSpace.xl,
                        RaSpace.xl,
                      ),
                      itemCount: providers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RaSpace.sm),
                      itemBuilder: (context, index) {
                        final provider = providers[index].data();
                        final name =
                            provider['displayName'] as String? ??
                            'Service Provider';
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(RaSpace.md),
                            leading: ProfileInitials(name: name),
                            title: Text(name, style: RaText.title),
                            subtitle: const Text(
                              'Online - accepting requests',
                              style: RaText.bodyMuted,
                            ),
                            trailing: const StatusPill(
                              label: 'Available',
                              tone: RaTone.success,
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
