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
      chatInbox = ChatInboxController(
        isProvider: false,
      );
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
    if (!firebaseReady) return _buildDashboard(context);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (enforceEmailVerification && user != null && !user.emailVerified) {
          return const EmailVerificationScreen(role: 'driver');
        }
        return _buildDashboard(context);
      },
    );
  }

  Widget _buildDashboard(BuildContext context) {
    // Verification can finish while this shell is already mounted.
    if (signedIn && FirebaseAuth.instance.currentUser!.emailVerified) {
      chatInbox ??= ChatInboxController(isProvider: false);
    }
    final theme = Theme.of(context);

    final dark =
        theme.brightness == Brightness.dark;

    final pages = <Widget>[
      const DriverHomeScreen(),
      const HistoryScreen(),
      const _ChatInboxScreen(
        isProvider: false,
      ),
      const DriverProfileScreen(),
    ];

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (!didPop && index != 0) {
          setState(() {
            index = 0;
          });
        }
      },
      child: RaScaffold(
        backgroundColor: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFF4F8FC),
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar:
            _DriverBottomNavigation(
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

class _DriverBottomNavigation
    extends StatelessWidget {
  const _DriverBottomNavigation({
    required this.selectedIndex,
    required this.chatInbox,
    required this.onSelected,
  });

  final int selectedIndex;

  final ChatInboxController?
      chatInbox;

  final ValueChanged<int>
      onSelected;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final dark =
        theme.brightness ==
            Brightness.dark;

    return Material(
      color: dark
          ? const Color(0xFF07131E)
          : const Color(0xFFF4F8FC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            7,
            12,
            9,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: dark
                  ? const Color(
                      0xFF0D1D2B,
                    )
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
              border: Border.all(
                color: dark
                    ? Colors.white
                        .withValues(
                        alpha: .075,
                      )
                    : const Color(
                        0xFFDCE8F2,
                      ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha:
                        dark ? .24 : .07,
                  ),
                  blurRadius: 22,
                  offset:
                      const Offset(
                    0,
                    6,
                  ),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 68,
              child: NavigationBarTheme(
                data:
                    NavigationBarThemeData(
                  height: 68,
                  backgroundColor:
                      Colors.transparent,
                  elevation: 0,
                  indicatorColor: colors
                      .primary
                      .withValues(
                    alpha:
                        dark ? .18 : .10,
                  ),
                  labelTextStyle:
                      WidgetStateProperty
                          .resolveWith(
                    (
                      states,
                    ) {
                      final selected =
                          states.contains(
                        WidgetState
                            .selected,
                      );

                      return TextStyle(
                        fontSize: 11.5,
                        height: 1.1,
                        fontWeight:
                            selected
                                ? FontWeight
                                    .w700
                                : FontWeight
                                    .w500,
                        color: selected
                            ? colors.primary
                            : colors
                                .onSurfaceVariant,
                      );
                    },
                  ),
                  iconTheme:
                      WidgetStateProperty
                          .resolveWith(
                    (
                      states,
                    ) {
                      final selected =
                          states.contains(
                        WidgetState
                            .selected,
                      );

                      return IconThemeData(
                        size: 22,
                        color: selected
                            ? colors.primary
                            : colors
                                .onSurfaceVariant,
                      );
                    },
                  ),
                ),
                child: NavigationBar(
                  selectedIndex:
                      selectedIndex,
                  onDestinationSelected:
                      onSelected,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(
                        Icons
                            .home_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons
                            .home_rounded,
                      ),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(
                        Icons
                            .receipt_long_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons
                            .receipt_long_rounded,
                      ),
                      label: 'Requests',
                    ),
                    NavigationDestination(
                      icon:
                          _DriverMessagesIcon(
                        controller:
                            chatInbox,
                        selected: false,
                      ),
                      selectedIcon:
                          _DriverMessagesIcon(
                        controller:
                            chatInbox,
                        selected: true,
                      ),
                      label: 'Messages',
                    ),
                    const NavigationDestination(
                      icon: Icon(
                        Icons
                            .person_outline_rounded,
                      ),
                      selectedIcon: Icon(
                        Icons
                            .person_rounded,
                      ),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE ICON + LIVE UNREAD BADGE
// ============================================================

class _DriverMessagesIcon
    extends StatelessWidget {
  const _DriverMessagesIcon({
    required this.controller,
    required this.selected,
  });

  final ChatInboxController?
      controller;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final inbox =
        controller;

    if (inbox == null) {
      return _DriverMessagesBadge(
        unread: 0,
        selected: selected,
      );
    }

    return AnimatedBuilder(
      animation: inbox,
      builder: (
        context,
        _,
      ) {
        return _DriverMessagesBadge(
          unread: inbox.unread,
          selected: selected,
        );
      },
    );
  }
}

class _DriverMessagesBadge
    extends StatelessWidget {
  const _DriverMessagesBadge({
    required this.unread,
    required this.selected,
  });

  final int unread;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible:
          unread > 0,
      backgroundColor:
          const Color(
        0xFFD8362A,
      ),
      textColor: Colors.white,
      label: Text(
        unread > 99
            ? '99+'
            : '$unread',
        style: const TextStyle(
          fontSize: 8,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      child: Icon(
        selected
            ? Icons
                .chat_bubble_rounded
            : Icons
                .chat_bubble_outline_rounded,
      ),
    );
  }
}