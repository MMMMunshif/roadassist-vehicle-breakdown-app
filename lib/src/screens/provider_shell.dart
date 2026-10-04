part of '../screens.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && index != 0) setState(() => index = 0);
    },
    child: Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ProviderHomeScreen(),
          ProviderNotificationsScreen(),
          ProviderHistoryScreen(),
          ProviderProfileScreen(),
          SupportScreen(isProvider: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Help',
          ),
        ],
      ),
    ),
  );
}

bool _requestMatchesProvider(
  Map<String, dynamic> data,
  String userId, {
  List<String>? services,
}) {
  final rejected = data['rejectedBy'] as List<dynamic>? ?? const [];
  final preferredProviderId = data['preferredProviderId'] as String? ?? '';
  final isPreferred =
      preferredProviderId.isEmpty || preferredProviderId == userId;
  final supportsService =
      services == null || services.contains(data['issue'] as String? ?? '');
  return isPreferred && !rejected.contains(userId) && supportsService;
}
