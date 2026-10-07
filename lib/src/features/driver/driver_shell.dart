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

    if (signedIn) {
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
    if (value == index) return;

    setState(() {
      index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          setState(() {
            index = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFF4F8FC),
        body: IndexedStack(
          index: index,
          children: pages,
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
// PREMIUM DRIVER NAVIGATION
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        color: dark
            ? const Color(0xFF07131E)
            : const Color(0xFFF4F8FC),
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          10,
        ),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 68,
          ),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF0D1D2B)
                : Colors.white,
            borderRadius: BorderRadius.circular(
              24,
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(
                      alpha: .075,
                    )
                  : const Color(
                      0xFFDCE8F2,
                    ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: dark ? .28 : .08,
                ),
                blurRadius: 28,
                offset: const Offset(
                  0,
                  8,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _DriverNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon:
                      Icons.home_rounded,
                  label: 'Home',
                  selected:
                      selectedIndex == 0,
                  onTap: () {
                    onSelected(0);
                  },
                ),
              ),

              Expanded(
                child: _DriverNavItem(
                  icon:
                      Icons.receipt_long_outlined,
                  selectedIcon:
                      Icons.receipt_long_rounded,
                  label: 'Requests',
                  selected:
                      selectedIndex == 1,
                  onTap: () {
                    onSelected(1);
                  },
                ),
              ),

              Expanded(
                child: _DriverMessagesNavItem(
                  controller: chatInbox,
                  selected:
                      selectedIndex == 2,
                  onTap: () {
                    onSelected(2);
                  },
                ),
              ),

              Expanded(
                child: _DriverNavItem(
                  icon:
                      Icons.person_outline_rounded,
                  selectedIcon:
                      Icons.person_rounded,
                  label: 'Profile',
                  selected:
                      selectedIndex == 3,
                  onTap: () {
                    onSelected(3);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STANDARD NAV ITEM
// ============================================================

class _DriverNavItem extends StatelessWidget {
  const _DriverNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;

  final String label;
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    final activeColor = dark
        ? const Color(0xFF72BEFF)
        : const Color(0xFF0963BA);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          19,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            19,
          ),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(
                      alpha: dark ? .14 : .09,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                19,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  curve: Curves.easeOutCubic,
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withValues(
                            alpha:
                                dark ? .16 : .11,
                          )
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      selected
                          ? selectedIcon
                          : icon,
                      size: 21,
                      color: selected
                          ? activeColor
                          : colors
                              .onSurfaceVariant
                              .withValues(
                            alpha: .74,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style:
                        GoogleFonts.plusJakartaSans(
                      fontSize: 9.8,
                      height: 1.1,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? activeColor
                          : colors
                              .onSurfaceVariant
                              .withValues(
                            alpha: .78,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE TAB WITH LIVE UNREAD BADGE
// ============================================================

class _DriverMessagesNavItem
    extends StatelessWidget {
  const _DriverMessagesNavItem({
    required this.controller,
    required this.selected,
    required this.onTap,
  });

  final ChatInboxController? controller;
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inbox = controller;

    if (inbox == null) {
      return _DriverMessagesNavVisual(
        unread: 0,
        selected: selected,
        onTap: onTap,
      );
    }

    return AnimatedBuilder(
      animation: inbox,
      builder: (context, _) {
        return _DriverMessagesNavVisual(
          unread: inbox.unread,
          selected: selected,
          onTap: onTap,
        );
      },
    );
  }
}

class _DriverMessagesNavVisual
    extends StatelessWidget {
  const _DriverMessagesNavVisual({
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final int unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    final activeColor = dark
        ? const Color(0xFF72BEFF)
        : const Color(0xFF0963BA);

    return Semantics(
      selected: selected,
      button: true,
      label: unread > 0
          ? 'Messages, $unread unread'
          : 'Messages',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          19,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            19,
          ),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(
              minHeight: 56,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(
                      alpha: dark ? .14 : .09,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                19,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  curve: Curves.easeOutCubic,
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withValues(
                            alpha:
                                dark ? .16 : .11,
                          )
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                  child: Center(
                    child: Badge(
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
                        style:
                            GoogleFonts.plusJakartaSans(
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
                        size: 21,
                        color: selected
                            ? activeColor
                            : colors
                                .onSurfaceVariant
                                .withValues(
                              alpha: .74,
                            ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Messages',
                    maxLines: 1,
                    style:
                        GoogleFonts.plusJakartaSans(
                      fontSize: 9.8,
                      height: 1.1,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? activeColor
                          : colors
                              .onSurfaceVariant
                              .withValues(
                            alpha: .78,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}