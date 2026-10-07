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
      chatInbox = ChatInboxController(isProvider: false);
    }
  }

  @override
  void dispose() {
    chatInbox?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
          setState(() => index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: .55),
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              height: 72,
              elevation: 0,
              backgroundColor: colors.surface,
              indicatorColor: colors.primaryContainer,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) {
                if (index == value) return;
                setState(() => index = value);
              },
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
                  icon: _DriverMessagesNavIcon(
                    controller: chatInbox,
                    selected: false,
                  ),
                  selectedIcon: _DriverMessagesNavIcon(
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
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverMessagesNavIcon extends StatelessWidget {
  const _DriverMessagesNavIcon({
    required this.controller,
    required this.selected,
  });

  final ChatInboxController? controller;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final inbox = controller;

    if (inbox == null) {
      return Icon(
        selected
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
      );
    }

    return AnimatedBuilder(
      animation: inbox,
      builder: (context, _) {
        final unread = inbox.unread;

        return Badge(
          isLabelVisible: unread > 0,
          label: Text(
            unread > 99 ? '99+' : '$unread',
          ),
          child: Icon(
            selected
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
          ),
        );
      },
    );
  }
}