part of '../../screens.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int index = 0;

  ChatInboxController? chatInbox;

  @override
  void initState() {
    super.initState();

    if (signedIn && FirebaseAuth.instance.currentUser!.emailVerified) {
      chatInbox = ChatInboxController(isProvider: false);
    }
  }

  @override
  void dispose() {
    chatInbox?.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    if (value == index) {
      return;
    }

    setState(() {
      index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady)
      return RaDriverTheme(child: Builder(builder: _buildDashboard));
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (enforceEmailVerification && user != null && !user.emailVerified) {
          return const EmailVerificationScreen(role: 'driver');
        }
        return RoleEmailGate(
          role: 'driver',
          child: RaDriverTheme(child: Builder(builder: _buildDashboard)),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context) {
    // Verification can finish while this shell is already mounted.
    if (signedIn && FirebaseAuth.instance.currentUser!.emailVerified) {
      chatInbox ??= ChatInboxController(isProvider: false);
    }
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;

    final pages = <Widget>[
      const DriverHomeScreen(),
      const HistoryScreen(),
      const _ChatInboxScreen(isProvider: false),
      const DriverProfileScreen(),
    ];

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          setState(() {
            index = 0;
          });
        }
      },
      child: RaDriverScaffold(
        extendBody: true,
        backgroundColor: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFF4F8FC),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: index, children: pages),
        ),
        bottomNavigationBar: _DriverBottomNavigation(
          selectedIndex: index,
          chatInbox: chatInbox,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

// ============================================================
// DRIVER BOTTOM NAVIGATION
// ============================================================

class _DriverBottomNavigation extends StatelessWidget {
  const _DriverBottomNavigation({
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
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Requests',
      ),
      NavigationDestination(
        icon: _DriverMessagesIcon(controller: chatInbox, selected: false),
        selectedIcon: _DriverMessagesIcon(
          controller: chatInbox,
          selected: true,
        ),
        label: 'Messages',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
}

// ============================================================
// MESSAGE ICON + LIVE UNREAD BADGE
// ============================================================

class _DriverMessagesIcon extends StatelessWidget {
  const _DriverMessagesIcon({required this.controller, required this.selected});

  final ChatInboxController? controller;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final inbox = controller;

    if (inbox == null) {
      return _DriverMessagesBadge(unread: 0, selected: selected);
    }

    return AnimatedBuilder(
      animation: inbox,
      builder: (context, _) {
        return _DriverMessagesBadge(unread: inbox.unread, selected: selected);
      },
    );
  }
}

class _DriverMessagesBadge extends StatelessWidget {
  const _DriverMessagesBadge({required this.unread, required this.selected});

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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Icon(
        selected
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
      ),
    );
  }
}

/// Floating member navigation shared by driver and provider shells.
class RaFloatingNavigation extends StatelessWidget {
  const RaFloatingNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    const blue = Color(0xFF007AFF);
    final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final height = 76.0 + (scale.clamp(1.0, 2.0) - 1) * 18;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            const Color(0xFF173852).withValues(alpha: .76),
                            const Color(0xFF0B2238).withValues(alpha: .62),
                          ]
                        : [
                            Colors.white.withValues(alpha: .82),
                            const Color(0xFFE8F4FF).withValues(alpha: .64),
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .20 : .72),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: SizedBox(
                    height: height - 14,
                    child: Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: Semantics(
                              selected: i == selectedIndex,
                              button: true,
                              label: destinations[i].label,
                              child: Tooltip(
                                message:
                                    destinations[i].tooltip ??
                                    destinations[i].label,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(25),
                                    onTap: () => onSelected(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: i == selectedIndex
                                            ? blue.withValues(alpha: .90)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: ExcludeSemantics(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconTheme(
                                              data: IconThemeData(
                                                size: 23,
                                                color: i == selectedIndex
                                                    ? Colors.white
                                                    : colors.onSurfaceVariant,
                                              ),
                                              child: i == selectedIndex
                                                  ? destinations[i]
                                                            .selectedIcon ??
                                                        destinations[i].icon
                                                  : destinations[i].icon,
                                            ),
                                            const SizedBox(height: 5),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: Text(
                                                destinations[i].label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize:
                                                          destinations.length ==
                                                              5
                                                          ? 10
                                                          : 11,
                                                      fontWeight:
                                                          i == selectedIndex
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: i == selectedIndex
                                                          ? Colors.white
                                                          : colors
                                                                .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
