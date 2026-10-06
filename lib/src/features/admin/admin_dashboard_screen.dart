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
  List<int> get visibleTabs => accessRole == 'reviewer'
      ? [0, 1, 4, 5, 6]
      : accessRole == 'support'
      ? [0, 2, 3, 4, 5, 6, 7, 8]
      : List.generate(tabs.length, (i) => i);
  @override
  void initState() {
    super.initState();
    unawaited(loadAccessRole());
  }

  Future<void> loadAccessRole() async {
    try {
      final access = await FirebaseFirestore.instance
          .collection('adminAccess')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (mounted)
        setState(
          () => accessRole = access.data()?['role'] as String? ?? 'super_admin',
        );
    } catch (_) {}
  }

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
    Icons.people_outline,
    Icons.support_agent,
    Icons.route_outlined,
    Icons.history,
    Icons.monitor_heart_outlined,
    Icons.payments_outlined,
    Icons.bar_chart,
    Icons.settings_outlined,
    Icons.admin_panel_settings_outlined,
  ];
  static const descriptions = [
    'Your live operations at a glance',
    'Review provider accounts and verification',
    'Find and manage RoadAssist accounts',
    'Review reports, evidence and decisions',
    'Monitor assistance and service progress',
    'Trace administrative decisions',
    'Review waiting requests and delayed updates',
    'Reconcile manually reported payments',
    'Explore and export loaded job metrics',
    'Manage notices and service availability',
    'Review private administrative access',
  ];

  Widget content() => switch (tab) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final colors = Theme.of(context).colorScheme;
          return Row(
            children: [
              if (wide)
                Container(
                  width: 210,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 30, 24, 4),
                        child: Text(
                          'RoadAssist',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        child: Text(
                          'ADMIN WORKSPACE',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final i in visibleTabs)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: tab == i,
                                  selectedTileColor: colors.primaryContainer,
                                  selectedColor: colors.onPrimaryContainer,
                                  leading: Icon(icons[i]),
                                  title: Text(tabs[i]),
                                  onTap: () => setState(() => tab = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Private access\nAll moderation actions are audited.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 24, 16, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tabs[tab],
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  descriptions[tab],
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onSignOut,
                            tooltip: 'Sign out',
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),
                    ),
                    if (!wide)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            for (final i in visibleTabs)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 12,
                                ),
                                child: ChoiceChip(
                                  avatar: Icon(icons[i], size: 18),
                                  label: Text(tabs[i]),
                                  selected: tab == i,
                                  onSelected: (_) => setState(() => tab = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 20 : 12),
                        child: content(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
