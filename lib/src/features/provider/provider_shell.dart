part of '../../screens.dart';

class ApprovedProviderShell extends StatefulWidget {
  const ApprovedProviderShell({super.key});

  @override
  State<ApprovedProviderShell> createState() => _ApprovedProviderShellState();
}

class _ApprovedProviderShellState extends State<ApprovedProviderShell> {
  int index = 0;

  ChatInboxController? chatInbox;

  static const pages = <Widget>[
    ProviderHomeScreen(),
    ProviderNotificationsScreen(),
    ProviderHistoryScreen(),
    _ChatInboxScreen(isProvider: true),
    ProviderProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    if (signedIn) {
      chatInbox = ChatInboxController(isProvider: true);
    }
  }

  @override
  void dispose() {
    chatInbox?.dispose();
    super.dispose();
  }

  void _changeTab(int value) {
    if (value == index) {
      return;
    }

    setState(() {
      index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          setState(() {
            index = 0;
          });
        }
      },
      child: RaProviderScaffold(
        extendBody: true,
        backgroundColor: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFF5F8FC),
        body: _ProviderNavigationScope(
          onSelected: _changeTab,
          child: SafeArea(
            top: false,
            child: IndexedStack(index: index, children: pages),
          ),
        ),
        bottomNavigationBar: _ProviderBottomNavigation(
          selectedIndex: index,
          chatInbox: chatInbox,
          onSelected: _changeTab,
        ),
      ),
    );
  }
}

// ============================================================
// PROVIDER BOTTOM NAVIGATION
// ============================================================

class _ProviderBottomNavigation extends StatelessWidget {
  const _ProviderBottomNavigation({
    required this.selectedIndex,
    required this.chatInbox,
    required this.onSelected,
  });

  final int selectedIndex;
  final ChatInboxController? chatInbox;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => RaFloatingNavigation(
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    destinations: [
      const NavigationDestination(
        tooltip: 'Dashboard',
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Dashboard',
      ),

      const NavigationDestination(
        tooltip: 'Requests',
        icon: Icon(Icons.inbox_outlined),
        selectedIcon: Icon(Icons.inbox_rounded),
        label: 'Requests',
      ),

      const NavigationDestination(
        tooltip: 'Jobs',
        icon: Icon(Icons.work_history_outlined),
        selectedIcon: Icon(Icons.work_history_rounded),
        label: 'Jobs',
      ),

      NavigationDestination(
        tooltip: 'Messages',
        icon: _ProviderMessagesIcon(controller: chatInbox, selected: false),
        selectedIcon: _ProviderMessagesIcon(
          controller: chatInbox,
          selected: true,
        ),
        label: 'Messages',
      ),

      const NavigationDestination(
        tooltip: 'Profile',
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
}

// ============================================================
// MESSAGE BADGE
// ============================================================

class _ProviderMessagesIcon extends StatelessWidget {
  const _ProviderMessagesIcon({
    required this.controller,
    required this.selected,
  });

  final ChatInboxController? controller;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final inbox = controller;

    if (inbox == null) {
      return _ProviderMessageBadge(unread: 0, selected: selected);
    }

    return AnimatedBuilder(
      animation: inbox,
      builder: (context, _) {
        return _ProviderMessageBadge(unread: inbox.unread, selected: selected);
      },
    );
  }
}

class _ProviderMessageBadge extends StatelessWidget {
  const _ProviderMessageBadge({required this.unread, required this.selected});

  final int unread;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unread > 0,
      backgroundColor: const Color(0xFFD8362A),
      textColor: Colors.white,
      label: Text(
        unread > 99 ? '99+' : '$unread',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Icon(
        selected
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
      ),
    );
  }
}

// ============================================================
// PROVIDER REQUEST MATCHING
// ============================================================

bool _requestMatchesProvider(
  Map<String, dynamic> data,
  String userId, {
  List<String>? services,
}) {
  if (data['driverId'] == userId) return false;

  final rejected = data['rejectedBy'] as List<dynamic>? ?? const [];

  final preferredProviderId = data['preferredProviderId'] as String? ?? '';

  final isPreferred =
      preferredProviderId.isEmpty || preferredProviderId == userId;

  if (!isPreferred || rejected.contains(userId)) {
    return false;
  }

  if (services == null) {
    return true;
  }

  final providerServices = services
      .map((service) => service.trim())
      .where((service) => service.isNotEmpty)
      .toSet();

  if (providerServices.isEmpty) {
    return false;
  }

  final requestIssues = (data['issues'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((issue) => issue.trim())
      .where((issue) => issue.isNotEmpty)
      .toList();

  if (requestIssues.isNotEmpty) {
    return requestIssues.every(providerServices.contains);
  }

  final issue = data['issue'] as String? ?? '';

  return issue.trim().isNotEmpty && providerServices.contains(issue.trim());
}
