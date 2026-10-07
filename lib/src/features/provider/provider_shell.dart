part of '../../screens.dart';

class ApprovedProviderShell extends StatefulWidget {
  const ApprovedProviderShell({
    super.key,
  });

  @override
  State<ApprovedProviderShell> createState() =>
      _ApprovedProviderShellState();
}

class _ApprovedProviderShellState
    extends State<ApprovedProviderShell> {
  int index = 0;

  final pages = const [
    ProviderHomeScreen(),
    ProviderNotificationsScreen(),
    ProviderHistoryScreen(),
    _ChatInboxScreen(
      isProvider: true,
    ),
    ProviderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (!didPop &&
            index != 0) {
          setState(() {
            index = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar:
            NavigationBar(
          selectedIndex: index,
          onDestinationSelected:
              (value) {
            setState(() {
              index = value;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons
                    .dashboard_outlined,
              ),
              selectedIcon: Icon(
                Icons
                    .dashboard_rounded,
              ),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(
                Icons
                    .inbox_outlined,
              ),
              selectedIcon: Icon(
                Icons
                    .inbox_rounded,
              ),
              label: 'Requests',
            ),
            NavigationDestination(
              icon: Icon(
                Icons
                    .work_history_outlined,
              ),
              selectedIcon: Icon(
                Icons
                    .work_history_rounded,
              ),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: Icon(
                Icons
                    .chat_bubble_outline_rounded,
              ),
              selectedIcon: Icon(
                Icons
                    .chat_bubble_rounded,
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(
                Icons
                    .person_outline_rounded,
              ),
              selectedIcon: Icon(
                Icons.person_rounded,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

bool _requestMatchesProvider(
  Map<String, dynamic> data,
  String userId, {
  List<String>? services,
}) {
  final rejected =
      data['rejectedBy']
              as List<dynamic>? ??
          const [];

  final preferredProviderId =
      data['preferredProviderId']
              as String? ??
          '';

  final isPreferred =
      preferredProviderId.isEmpty ||
          preferredProviderId ==
              userId;

  final supportsService =
      services == null ||
          services.contains(
            data['issue']
                    as String? ??
                '',
          );

  return isPreferred &&
      !rejected.contains(userId) &&
      supportsService;
}