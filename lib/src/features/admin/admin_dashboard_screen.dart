part of '../../screens.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int tab = 0;

  String accessRole = 'support';
  bool loadingRole = true;

  static const tabs = [
    'Overview',
    'Providers',
    'Users',
    'Complaints',
    'Jobs',
    'Audit',
    'Operations',
    'Payments',
    'Reports',
    'Settings',
    'Admin team',
  ];

  static const icons = [
    Icons.dashboard_outlined,
    Icons.handyman_outlined,
    Icons.people_outline_rounded,
    Icons.support_agent_outlined,
    Icons.route_outlined,
    Icons.history_rounded,
    Icons.monitor_heart_outlined,
    Icons.payments_outlined,
    Icons.bar_chart_rounded,
    Icons.settings_outlined,
    Icons.admin_panel_settings_outlined,
  ];

  static const selectedIcons = [
    Icons.dashboard_rounded,
    Icons.handyman_rounded,
    Icons.people_rounded,
    Icons.support_agent_rounded,
    Icons.route_rounded,
    Icons.history_rounded,
    Icons.monitor_heart_rounded,
    Icons.payments_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
    Icons.admin_panel_settings_rounded,
  ];

  static const descriptions = [
    'Live RoadAssist operations at a glance.',
    'Review provider accounts, documents and verification.',
    'Find and review RoadAssist user accounts.',
    'Review service reports, evidence and case decisions.',
    'Monitor assistance requests and service progress.',
    'Trace administrative actions and decisions.',
    'Identify waiting requests and delayed active jobs.',
    'Review manually reported and confirmed payments.',
    'Explore loaded operational metrics and exports.',
    'Manage service availability and public notices.',
    'Review private administrative access roles.',
  ];

  List<int> get visibleTabs {
    if (accessRole == 'reviewer') {
      return [0, 1, 4, 5, 6];
    }

    if (accessRole == 'support') {
      return [0, 2, 3, 4, 5, 6, 7, 8];
    }

    return List.generate(tabs.length, (index) => index);
  }

  String get roleLabel {
    return switch (accessRole) {
      'super_admin' => 'Super Admin',
      'reviewer' => 'Provider Reviewer',
      'support' => 'Support',
      _ => accessRole.replaceAll('_', ' '),
    };
  }

  IconData get roleIcon {
    return switch (accessRole) {
      'super_admin' => Icons.security_rounded,
      'reviewer' => Icons.verified_user_outlined,
      _ => Icons.support_agent_outlined,
    };
  }

  @override
  void initState() {
    super.initState();

    unawaited(loadAccessRole());
  }

  Future<void> loadAccessRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        return;
      }

      final access = await FirebaseFirestore.instance
          .collection('adminAccess')
          .doc(currentUser.uid)
          .get();

      if (!mounted) {
        return;
      }

      final role = access.data()?['role'] as String? ?? 'super_admin';

      final allowed = role == 'reviewer'
          ? [0, 1, 4, 5, 6]
          : role == 'support'
          ? [0, 2, 3, 4, 5, 6, 7, 8]
          : List.generate(tabs.length, (index) => index);

      setState(() {
        accessRole = role;

        if (!allowed.contains(tab)) {
          tab = allowed.first;
        }
      });
    } catch (_) {
      // Firestore/security rules remain authoritative.
    } finally {
      if (mounted) {
        setState(() {
          loadingRole = false;
        });
      }
    }
  }

  Widget content() {
    return switch (tab) {
      0 => const AdminOverviewScreen(),
      1 => const AdminProvidersScreen(),
      2 => const AdminUsersScreen(),
      3 => const AdminComplaintsScreen(),
      4 => const AdminJobsScreen(),
      5 => const AdminAuditScreen(),
      6 => const AdminOperationsScreen(),
      7 => const AdminPaymentsScreen(),
      8 => const AdminReportsScreen(),
      9 => const AdminSettingsScreen(),
      _ => const AdminTeamScreen(),
    };
  }

  void selectTab(int value) {
    if (tab == value) {
      return;
    }

    setState(() {
      tab = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            if (desktop) {
              return Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: _AdminDashboardSidebar(
                      tab: tab,
                      visibleTabs: visibleTabs,
                      tabs: tabs,
                      icons: icons,
                      selectedIcons: selectedIcons,
                      roleLabel: roleLabel,
                      roleIcon: roleIcon,
                      loadingRole: loadingRole,
                      onSelected: selectTab,
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant.withValues(alpha: .50),
                  ),
                  Expanded(
                    child: _AdminDashboardWorkspace(
                      tab: tab,
                      title: tabs[tab],
                      description: descriptions[tab],
                      onSignOut: widget.onSignOut,
                      child: content(),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _AdminDashboardMobileHeader(
                  title: tabs[tab],
                  description: descriptions[tab],
                  roleLabel: loadingRole ? 'Checking access…' : roleLabel,
                  onSignOut: widget.onSignOut,
                ),
                _AdminDashboardMobileTabs(
                  tab: tab,
                  visibleTabs: visibleTabs,
                  tabs: tabs,
                  icons: icons,
                  onSelected: selectTab,
                ),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: .50),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Material(color: colors.surface, child: content()),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminDashboardSidebar extends StatelessWidget {
  const _AdminDashboardSidebar({
    required this.tab,
    required this.visibleTabs,
    required this.tabs,
    required this.icons,
    required this.selectedIcons,
    required this.roleLabel,
    required this.roleIcon,
    required this.loadingRole,
    required this.onSelected,
    required this.onSignOut,
  });

  final int tab;
  final List<int> visibleTabs;
  final List<String> tabs;
  final List<IconData> icons;
  final List<IconData> selectedIcons;

  final String roleLabel;
  final IconData roleIcon;
  final bool loadingRole;

  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D1D2B)
          : colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF075BA8), Color(0xFF087D78)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RoadAssist',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.35,
                        ),
                      ),
                      Text(
                        'ADMIN WORKSPACE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .85,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(roleIcon, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loadingRole ? 'Checking access…' : roleLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              children: [
                for (final index in visibleTabs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _AdminDashboardNavItem(
                      icon: tab == index ? selectedIcons[index] : icons[index],
                      label: tabs[index],
                      selected: tab == index,
                      onTap: () {
                        onSelected(index);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: .35,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Private access. Administrative actions are audited.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(onSignOut());
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardNavItem extends StatelessWidget {
  const _AdminDashboardNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .085)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? colors.primary : null,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboardWorkspace extends StatelessWidget {
  const _AdminDashboardWorkspace({
    required this.tab,
    required this.title,
    required this.description,
    required this.onSignOut,
    required this.child,
  });

  final int tab;
  final String title;
  final String description;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(25, 18, 20, 17),
          color: colors.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const _WelcomeThemeToggle(),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  unawaited(onSignOut());
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .50)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(color: colors.surface, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminDashboardMobileHeader extends StatelessWidget {
  const _AdminDashboardMobileHeader({
    required this.title,
    required this.description,
    required this.roleLabel,
    required this.onSignOut,
  });

  final String title;
  final String description;
  final String roleLabel;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 10, 12),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.shield_outlined, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const _WelcomeThemeToggle(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              unawaited(onSignOut());
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardMobileTabs extends StatelessWidget {
  const _AdminDashboardMobileTabs({
    required this.tab,
    required this.visibleTabs,
    required this.tabs,
    required this.icons,
    required this.onSelected,
  });

  final int tab;
  final List<int> visibleTabs;
  final List<String> tabs;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44 + MediaQuery.textScalerOf(context).scale(16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        itemCount: visibleTabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, position) {
          final index = visibleTabs[position];

          return ChoiceChip(
            avatar: Icon(icons[index], size: 16),
            label: Text(tabs[index]),
            selected: tab == index,
            onSelected: (_) {
              onSelected(index);
            },
          );
        },
      ),
    );
  }
}
