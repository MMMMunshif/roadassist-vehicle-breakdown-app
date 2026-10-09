part of '../../screens.dart';

class _AdminRecords extends StatefulWidget {
  const _AdminRecords({super.key, required this.kind});

  final String kind;

  @override
  State<_AdminRecords> createState() => _AdminRecordsState();
}

class _AdminRecordsState extends State<_AdminRecords> {
  final identityService = AdminIdentityService();
  final auditLookups = <String, Future<Map<String, String>>>{};
  int limit = 50;

  String search = '';
  String userRole = 'all';

  bool onlyAttention = false;

  late Stream<QuerySnapshot<Map<String, dynamic>>> records;

  @override
  void initState() {
    super.initState();

    connect();
  }

  @override
  void didUpdateWidget(covariant _AdminRecords oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.kind != widget.kind) {
      limit = 50;
      search = '';
      onlyAttention = false;
      userRole = 'all';

      connect();
    }
  }

  void connect() {
    final db = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> query = switch (widget.kind) {
      'providers' =>
        db
            .collection('users')
            .where(
              Filter.or(
                Filter('role', isEqualTo: 'provider'),
                Filter('roles', arrayContains: 'provider'),
              ),
            ),
      'users' => db.collection('users'),
      'complaints' => db.collectionGroup('disputes'),
      'jobs' =>
        db.collection('requests').orderBy('createdAt', descending: true),
      _ => db.collection('adminAudit').orderBy('createdAt', descending: true),
    };

    if (widget.kind == 'users' && userRole != 'all') {
      query = query.where(
        Filter.or(
          Filter('role', isEqualTo: userRole),
          Filter('roles', arrayContains: userRole),
        ),
      );
    }

    records = query.limit(limit).snapshots();
  }

  String get sectionTitle {
    return switch (widget.kind) {
      'providers' => 'Provider approvals',
      'users' => 'Users',
      'complaints' => 'Service complaints',
      'jobs' => 'Assistance jobs',
      _ => 'Administrative audit',
    };
  }

  String get sectionDescription {
    return switch (widget.kind) {
      'providers' =>
        'Review provider accounts, verification status and service access.',
      'users' => 'Search and review registered RoadAssist accounts.',
      'complaints' =>
        'Review driver reports, provider responses and unresolved cases.',
      'jobs' =>
        'Monitor roadside assistance requests and active service progress.',
      _ => 'Trace administrative actions, actors and recorded reasons.',
    };
  }

  IconData get sectionIcon {
    return switch (widget.kind) {
      'providers' => Icons.handyman_outlined,
      'users' => Icons.people_outline_rounded,
      'complaints' => Icons.support_agent_outlined,
      'jobs' => Icons.route_outlined,
      _ => Icons.history_rounded,
    };
  }

  String get searchHint {
    return switch (widget.kind) {
      'providers' => 'Name, email, role or status',
      'users' => 'Name, email or role',
      'complaints' => 'Reason, description or status',
      'jobs' => 'Driver, provider, issue or status',
      _ => 'Actor, action, target or reason',
    };
  }

  String get attentionTitle {
    return switch (widget.kind) {
      'jobs' => 'Only active jobs',
      'providers' => 'Only pending verification',
      'complaints' => 'Only unresolved reports',
      _ => '',
    };
  }

  String get attentionDescription {
    return switch (widget.kind) {
      'jobs' => 'Show accepted, en route and arrived jobs only.',
      'providers' => 'Focus on providers requiring verification review.',
      'complaints' => 'Hide reports already marked as resolved.',
      _ => '',
    };
  }

  bool get hasAttentionFilter {
    return widget.kind == 'jobs' ||
        widget.kind == 'complaints' ||
        widget.kind == 'providers';
  }

  String searchableText(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    return [
      document.id,
      data['email'],
      data['displayName'],
      data['driverName'],
      data['providerName'],
      data['role'],
      ...accountRoles(data),
      data['reason'],
      data['description'],
      data['issue'],
      ...(data['issues'] as List<dynamic>? ?? const []),
      data['target'],
      data['actor'],
      identityService.resolved[data['actor']]?.label,
      identityService.resolved[data['target']]?.label,
      if (widget.kind == 'audit') AdminAuditPresentation.action(data),
      data['status'],
    ].join(' ').toLowerCase();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> source,
  ) {
    return source.where((document) {
      final data = document.data();

      if (onlyAttention &&
          widget.kind == 'jobs' &&
          !const ['accepted', 'en_route', 'arrived'].contains(data['status'])) {
        return false;
      }

      if (onlyAttention &&
          widget.kind == 'complaints' &&
          data['status'] == 'resolved') {
        return false;
      }

      return searchableText(document).contains(search);
    }).toList();
  }

  void openRecord(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (widget.kind == 'users' || widget.kind == 'providers') {
      push(context, _AdminAccountScreen(uid: document.id));

      return;
    }

    if (widget.kind == 'complaints') {
      final requestReference = document.reference.parent.parent;

      if (requestReference == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to identify the related assistance request.'),
          ),
        );

        return;
      }

      push(context, _AdminComplaintScreen(requestId: requestReference.id));

      return;
    }

    if (widget.kind == 'jobs') {
      push(context, AdminJobMonitorScreen(requestId: document.id));

      return;
    }

    push(context, AdminAuditDetailScreen(data: document.data()));
  }

  String recordTitle(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    if (widget.kind == 'complaints') {
      return data['driverName'] as String? ??
          data['reason'] as String? ??
          'Driver report';
    }

    if (widget.kind == 'jobs') {
      return data['driverName'] as String? ?? 'Assistance request';
    }

    if (widget.kind == 'audit') {
      return AdminAuditPresentation.action(data);
    }

    return data['displayName'] as String? ?? document.id;
  }

  String recordSubtitle(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    if (widget.kind == 'complaints') {
      final reason =
          data['reason']?.toString().replaceAll('_', ' ') ?? 'Service problem';

      final description = data['description'] as String? ?? '';

      return description.trim().isEmpty ? reason : '$reason\n$description';
    }

    if (widget.kind == 'jobs') {
      final provider = data['providerName'] as String? ?? 'Unassigned provider';

      final issue = requestIssueLabel(data);

      final location =
          data['locationLabel'] as String? ??
          data['location'] as String? ??
          'Location not recorded';

      return '$provider • $issue\n$location';
    }

    if (widget.kind == 'audit') {
      final actor = data['actor']?.toString() ?? 'Unknown actor';

      final reason = data['reason']?.toString() ?? 'No reason recorded';

      return '$actor\n$reason';
    }

    return '';
  }

  IconData recordIcon() {
    return switch (widget.kind) {
      'jobs' => Icons.route_outlined,
      'complaints' => Icons.support_agent_outlined,
      _ => Icons.history_rounded,
    };
  }

  Color recordTone(BuildContext context, Map<String, dynamic> data) {
    final colors = Theme.of(context).colorScheme;

    final status = data['status']?.toString() ?? '';

    if (widget.kind == 'complaints') {
      return switch (status) {
        'resolved' => raSuccess,
        'under_review' => raGold,
        _ => colors.error,
      };
    }

    if (widget.kind == 'jobs') {
      return switch (status) {
        'completed' => raSuccess,
        'cancelled' || 'rejected' => colors.error,
        'en_route' || 'arrived' => colors.primary,
        _ => raGold,
      };
    }

    return colors.primary;
  }

  String? formattedTime(Map<String, dynamic> data) {
    final timestamp =
        data['updatedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;

    if (timestamp == null) {
      return null;
    }

    final value = timestamp.toDate().toLocal();

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 13),
          child: Column(
            children: [
              _AdminRecordsHeader(
                icon: sectionIcon,
                title: sectionTitle,
                description: sectionDescription,
              ),

              const SizedBox(height: 15),

              TextField(
                key: ValueKey(widget.kind),
                decoration: InputDecoration(
                  labelText: 'Search loaded records',
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            setState(() {
                              search = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    search = value.toLowerCase().trim();
                  });
                },
              ),

              if (widget.kind == 'users') ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdminUserRoleFilter(
                    selected: userRole,
                    onChanged: (value) {
                      setState(() {
                        userRole = value;
                        limit = 50;
                        connect();
                      });
                    },
                  ),
                ),
              ],

              if (hasAttentionFilter) ...[
                const SizedBox(height: 11),

                Container(
                  decoration: BoxDecoration(
                    color: onlyAttention
                        ? colors.primary.withValues(alpha: .065)
                        : colors.surfaceContainerHighest.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: onlyAttention
                          ? colors.primary.withValues(alpha: .18)
                          : colors.outlineVariant.withValues(alpha: .40),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 1,
                        ),
                        secondary: Icon(
                          onlyAttention
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          color: onlyAttention
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        title: Text(
                          attentionTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          attentionDescription,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        value: onlyAttention,
                        onChanged: (value) {
                          setState(() {
                            onlyAttention = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .45)),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey((widget.kind, userRole)),
          stream: records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load records',
                  message:
                      'Verify admin access, check your connection and try again.',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final loaded = snapshot.data!.docs;

            final docs = filteredDocuments(loaded);

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
              children: [
                _AdminRecordsSummary(
                  loaded: loaded.length,
                  matches: docs.length,
                  filtered: onlyAttention || search.isNotEmpty,
                ),

                const SizedBox(height: 14),

                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching records',
                      message:
                          'Try another search term or change the current filter.',
                    ),
                  )
                else if (widget.kind == 'providers' || widget.kind == 'users')
                  for (var index = 0; index < docs.length; index++) ...[
                    _AdminUserRow(
                      key: ValueKey(docs[index].id),
                      uid: docs[index].id,
                      data: docs[index].data(),
                      pendingOnly: widget.kind == 'providers' && onlyAttention,
                    ),
                    if (index != docs.length - 1) const SizedBox(height: 8),
                  ]
                else
                  for (var index = 0; index < docs.length; index++) ...[
                    FutureBuilder<Map<String, String>>(
                      future: widget.kind == 'audit'
                          ? auditLookups.putIfAbsent(
                              docs[index].id,
                              () => identityService.audit(docs[index].data()),
                            )
                          : null,
                      builder: (context, identity) => _AdminRecordCard(
                        document: docs[index],
                        kind: widget.kind,
                        title: recordTitle(docs[index]),
                        subtitle: widget.kind == 'audit'
                            ? 'Target: ${identity.data?['target'] ?? 'Loading details...'}\nBy: ${identity.data?['actor'] ?? 'Loading details...'}\n${docs[index].data()['reason'] ?? 'Reason not recorded'}'
                            : recordSubtitle(docs[index]),
                        icon: recordIcon(),
                        tone: recordTone(context, docs[index].data()),
                        time: formattedTime(docs[index].data()),
                        onTap: () {
                          openRecord(context, docs[index]);
                        },
                      ),
                    ),
                    if (index != docs.length - 1) const SizedBox(height: 8),
                  ],

                if (loaded.length == limit) ...[
                  const SizedBox(height: 17),

                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        limit += 50;
                        connect();
                      });
                    },
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Load 50 More · currently $limit'),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminRecordsHeader extends StatelessWidget {
  const _AdminRecordsHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .075),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.primary, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminRecordsSummary extends StatelessWidget {
  const _AdminRecordsSummary({
    required this.loaded,
    required this.matches,
    required this.filtered,
  });

  final int loaded;
  final int matches;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_outlined, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              filtered
                  ? '$loaded loaded • $matches match current search/filter'
                  : '$loaded records loaded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Tooltip(
            message:
                'Search and filters apply only to currently loaded records.',
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRecordCard extends StatelessWidget {
  const _AdminRecordCard({
    required this.document,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.time,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  final String kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final String? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final data = document.data();

    final status =
        data['status']?.toString() ??
        (kind == 'audit' ? data['state']?.toString() ?? '' : 'open');

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            time!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: kind == 'audit'
                            ? null
                            : kind == 'complaints'
                            ? 3
                            : 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (kind != 'audit' && status.isNotEmpty)
                          _AdminStatusBadge(status: status),
                        if (kind == 'audit' && status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tone.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: tone,
                              ),
                            ),
                          ),

                        Text(
                          kind == 'jobs'
                              ? 'Monitor'
                              : kind == 'complaints'
                              ? 'Review'
                              : 'Details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
