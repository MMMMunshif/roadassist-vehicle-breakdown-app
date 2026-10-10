part of '../../screens.dart';

const _driverActiveRequestStatuses = <String>{
  'searching',
  'accepted',
  'en_route',
  'arrived',
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  bool matchesFilter(String status) {
    return switch (filter) {
      1 => _driverActiveRequestStatuses.contains(status),
      2 => status == 'completed',
      3 => status == 'cancelled',
      _ => true,
    };
  }

  void openRequest(QueryDocumentSnapshot<Map<String, dynamic>> request) {
    final data = request.data();

    final status = data['status'] as String? ?? 'searching';

    final draft = requestDraftFromData(data);

    if (status == 'searching') {
      push(context, SearchingScreen(draft: draft, requestId: request.id));

      return;
    }

    if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
      push(context, TrackingScreen(draft: draft, requestId: request.id));

      return;
    }

    push(
      context,
      RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: RaDriverAppBarTitle(
          'Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              push(context, const DriverNotificationsScreen());
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a driver to view your assistance requests.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService().watchDriverRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load requests',
                      message: 'Check your connection and try again.',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const _RaHistoryLoading();
                }

                final all = snapshot.data!.docs.toList();

                all.sort((first, second) {
                  final firstTime = first.data()['createdAt'] as Timestamp?;

                  final secondTime = second.data()['createdAt'] as Timestamp?;

                  if (firstTime == null && secondTime == null) {
                    return 0;
                  }

                  if (firstTime == null) {
                    return 1;
                  }

                  if (secondTime == null) {
                    return -1;
                  }

                  return secondTime.compareTo(firstTime);
                });

                final activeCount = all.where((request) {
                  final status = request.data()['status'] as String? ?? '';

                  return _driverActiveRequestStatuses.contains(status);
                }).length;

                final completedCount = all.where((request) {
                  return request.data()['status'] == 'completed';
                }).length;

                final cancelledCount = all.where((request) {
                  return request.data()['status'] == 'cancelled';
                }).length;

                final filtered = all.where((request) {
                  final status = request.data()['status'] as String? ?? '';

                  return matchesFilter(status);
                }).toList();

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                  children: [
                    _RaHistoryHero(
                      active: activeCount,
                      completed: completedCount,
                      total: all.length,
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your assistance',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Track active roadside help and review previous requests.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Start assistance',
                          onPressed: () {
                            push(context, const AssistanceTypeScreen());
                          },
                          icon: const Icon(Icons.add_road_rounded),
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    _RaHistoryFilters(
                      selected: filter,
                      onSelected: (value) {
                        setState(() {
                          filter = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    if (filtered.isEmpty)
                      _RaHistoryEmpty(
                        filter: filter,
                        onStart: filter == 0
                            ? () {
                                push(context, const AssistanceTypeScreen());
                              }
                            : null,
                      )
                    else
                      for (var index = 0; index < filtered.length; index++) ...[
                        _RaHistoryCard(
                          request: filtered[index],
                          onTap: () {
                            openRequest(filtered[index]);
                          },
                        ),
                        if (index != filtered.length - 1)
                          const SizedBox(height: 9),
                      ],

                    if (cancelledCount > 0 && filter == 0) ...[
                      const SizedBox(height: 17),

                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: .28,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 17,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Cancelled requests remain available for reference.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _RaHistoryHero extends StatelessWidget {
  const _RaHistoryHero({
    required this.active,
    required this.completed,
    required this.total,
  });

  final int active;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your roadside requests',
          style: _providerText(context, size: 22, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          active > 0
              ? '$active active requests. Follow progress or open your service records.'
              : 'Track assistance, review completed jobs and download invoices.',
          style: _providerText(context, size: 14, muted: true),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final metric in [
                ('Active', active),
                ('Completed', completed),
                ('Total', total),
              ])
                SizedBox(
                  width: (box.maxWidth - 40) / 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${metric.$2}',
                        style: _providerText(
                          context,
                          size: 22,
                          weight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        metric.$1,
                        style: _providerText(context, size: 12, muted: true),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RaHistoryFilters extends StatelessWidget {
  const _RaHistoryFilters({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const filters = [
    ('All', Icons.apps_rounded),
    ('Active', Icons.route_outlined),
    ('Completed', Icons.check_circle_outline_rounded),
    ('Cancelled', Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            ChoiceChip(
              avatar: Icon(filters[index].$2, size: 15),
              label: Text(filters[index].$1),
              selected: selected == index,
              onSelected: (_) {
                onSelected(index);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RaHistoryCard extends StatelessWidget {
  const _RaHistoryCard({required this.request, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  final VoidCallback onTap;

  String statusLabel(String status) {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Provider arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
  }

  RaTone statusTone(String status) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'searching' => RaTone.warning,
      _ => RaTone.info,
    };
  }

  String dateLabel(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    final value = timestamp.toDate().toLocal();

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String? moneyLabel(Map<String, dynamic> data) {
    final value = data['finalCost'] as num? ?? data['estimatedCost'] as num?;

    if (value == null || value <= 0) {
      return null;
    }

    return 'Rs. ${value.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final data = request.data();

    final status = data['status'] as String? ?? 'searching';

    final provider = data['providerName']?.toString().trim() ?? '';

    final location =
        data['locationLabel']?.toString().trim() ??
        data['location']?.toString().trim() ??
        '';

    final amount = moneyLabel(data);

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.car_repair_outlined,
                      color: colors.primary,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestIssueLabel(data),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 5),

                        StatusPill(
                          label: statusLabel(status),
                          tone: statusTone(status),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 7),

                  Text(
                    dateLabel(data['createdAt'] as Timestamp?),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              if (provider.isNotEmpty || location.isNotEmpty) ...[
                const SizedBox(height: 12),

                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: .35),
                ),

                const SizedBox(height: 10),

                if (provider.isNotEmpty)
                  _RaHistoryLine(
                    icon: Icons.engineering_outlined,
                    text: provider,
                  ),

                if (provider.isNotEmpty && location.isNotEmpty)
                  const SizedBox(height: 6),

                if (location.isNotEmpty)
                  _RaHistoryLine(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  if (amount != null)
                    Text(
                      amount,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),

                  const Spacer(),

                  Text(
                    _driverActiveRequestStatuses.contains(status)
                        ? 'Resume'
                        : 'View details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
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
      ),
    );
  }
}

class _RaHistoryLine extends StatelessWidget {
  const _RaHistoryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _RaHistoryEmpty extends StatelessWidget {
  const _RaHistoryEmpty({required this.filter, this.onStart});

  final int filter;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final data = switch (filter) {
      1 => (
        Icons.route_outlined,
        'No active requests',
        'You do not have roadside assistance in progress.',
      ),
      2 => (
        Icons.check_circle_outline_rounded,
        'No completed requests',
        'Completed roadside assistance will appear here.',
      ),
      3 => (
        Icons.cancel_outlined,
        'No cancelled requests',
        'Cancelled requests will appear here.',
      ),
      _ => (
        Icons.receipt_long_outlined,
        'No requests yet',
        'Your roadside assistance requests will appear here.',
      ),
    };

    return Column(
      children: [
        EmptyState(icon: data.$1, title: data.$2, message: data.$3),
        if (onStart != null) ...[
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Start Assistance'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RaHistoryLoading extends StatelessWidget {
  const _RaHistoryLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          height: 165,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        const SizedBox(height: 22),
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 145,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}
