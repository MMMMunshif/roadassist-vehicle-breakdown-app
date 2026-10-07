part of '../../screens.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onSignOut,
  });

  final Future<void> Function() onSignOut;

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
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

    return List.generate(
      tabs.length,
      (index) => index,
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(loadAccessRole());
  }

  Future<void> loadAccessRole() async {
    try {
      final currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        return;
      }

      final access =
          await FirebaseFirestore.instance
              .collection('adminAccess')
              .doc(currentUser.uid)
              .get();

      if (!mounted) return;

      final role =
          access.data()?['role'] as String? ??
          'super_admin';

      final allowed = role == 'reviewer'
          ? [0, 1, 4, 5, 6]
          : role == 'support'
          ? [0, 2, 3, 4, 5, 6, 7, 8]
          : List.generate(
              tabs.length,
              (index) => index,
            );

      setState(() {
        accessRole = role;

        if (!allowed.contains(tab)) {
          tab = allowed.first;
        }
      });
    } catch (_) {
      // Existing access rules remain authoritative.
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

  String get roleLabel {
    return switch (accessRole) {
      'super_admin' => 'Super Admin',
      'reviewer' => 'Reviewer',
      'support' => 'Support',
      _ => accessRole.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop =
                constraints.maxWidth >= 980;

            return Row(
              children: [
                if (desktop)
                  Container(
                    width: 254,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        right: BorderSide(
                          color: colors.outlineVariant
                              .withValues(
                            alpha: .65,
                          ),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            22,
                            24,
                            22,
                            20,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    begin:
                                        Alignment.topLeft,
                                    end:
                                        Alignment
                                            .bottomRight,
                                    colors: [
                                      colors.primary,
                                      const Color(
                                        0xFF007D70,
                                      ),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: const Icon(
                                  Icons
                                      .shield_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(
                                width: RaSpace.md,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      'RoadAssist',
                                      style: theme
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight
                                                .w900,
                                      ),
                                    ),
                                    Text(
                                      'ADMIN WORKSPACE',
                                      style: theme
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        color: colors
                                            .onSurfaceVariant,
                                        letterSpacing:
                                            1.1,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .primaryContainer
                                  .withValues(
                                alpha: .35,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .admin_panel_settings_outlined,
                                  size: 18,
                                  color:
                                      colors.primary,
                                ),
                                const SizedBox(
                                  width:
                                      RaSpace.sm,
                                ),
                                Expanded(
                                  child: Text(
                                    loadingRole
                                        ? 'Loading access…'
                                        : roleLabel,
                                    style: theme
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: RaSpace.md,
                        ),

                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              10,
                              4,
                              10,
                              12,
                            ),
                            children: [
                              for (final i
                                  in visibleTabs)
                                Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    bottom: 4,
                                  ),
                                  child: Material(
                                    color: tab == i
                                        ? colors
                                            .primaryContainer
                                        : Colors
                                            .transparent,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                    clipBehavior:
                                        Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          tab = i;
                                        });
                                      },
                                      child: Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal:
                                              13,
                                          vertical:
                                              11,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              icons[i],
                                              size: 21,
                                              color: tab ==
                                                      i
                                                  ? colors
                                                      .onPrimaryContainer
                                                  : colors
                                                      .onSurfaceVariant,
                                            ),
                                            const SizedBox(
                                              width:
                                                  RaSpace
                                                      .md,
                                            ),
                                            Expanded(
                                              child:
                                                  Text(
                                                tabs[i],
                                                style: theme
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                  color: tab ==
                                                          i
                                                      ? colors
                                                          .onPrimaryContainer
                                                      : null,
                                                  fontWeight: tab ==
                                                          i
                                                      ? FontWeight
                                                          .w900
                                                      : FontWeight
                                                          .w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                              RaSpace.md,
                            ),
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .surfaceContainerHighest
                                  .withValues(
                                alpha: .42,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Icon(
                                  Icons
                                      .lock_outline_rounded,
                                  size: 17,
                                  color: colors
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(
                                  width:
                                      RaSpace.sm,
                                ),
                                Expanded(
                                  child: Text(
                                    'Private access. Administrative actions are audited.',
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 30 : 16,
                          desktop ? 24 : 16,
                          desktop ? 30 : 16,
                          18,
                        ),
                        color: colors.surface,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    tabs[tab],
                                    style: theme
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    descriptions[tab],
                                    style: theme
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color: colors
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              width: RaSpace.md,
                            ),

                            OutlinedButton.icon(
                              onPressed: () {
                                unawaited(
                                  widget.onSignOut(),
                                );
                              },
                              icon: const Icon(
                                Icons.logout_rounded,
                              ),
                              label: desktop
                                  ? const Text(
                                      'Sign out',
                                    )
                                  : const SizedBox
                                      .shrink(),
                            ),
                          ],
                        ),
                      ),

                      if (!desktop)
                        Container(
                          width: double.infinity,
                          color: colors.surface,
                          child:
                              SingleChildScrollView(
                            scrollDirection:
                                Axis.horizontal,
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            child: Row(
                              children: [
                                for (final i
                                    in visibleTabs)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .only(
                                      right: 7,
                                    ),
                                    child:
                                        ChoiceChip(
                                      avatar: Icon(
                                        icons[i],
                                        size: 17,
                                      ),
                                      label:
                                          Text(
                                        tabs[i],
                                      ),
                                      selected:
                                          tab == i,
                                      onSelected:
                                          (_) {
                                        setState(
                                          () {
                                            tab = i;
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      Divider(
                        height: 1,
                        color: colors.outlineVariant
                            .withValues(
                          alpha: .55,
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(
                            desktop ? 22 : 12,
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              desktop ? 22 : 16,
                            ),
                            child: Material(
                              color: colors.surface,
                              child: content(),
                            ),
                          ),
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
}