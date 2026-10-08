part of '../../screens.dart';

class ProviderHistoryScreen extends StatefulWidget {
  const ProviderHistoryScreen({
    super.key,
  });

  @override
  State<ProviderHistoryScreen> createState() =>
      _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState
    extends State<ProviderHistoryScreen> {
  int filter = 0;

  static const filters = <String>[
    'All',
    'Completed',
    'Cancelled',
  ];

  bool _matchesFilter(String status) {
    return switch (filter) {
      1 => status == 'completed',
      2 => status == 'cancelled',
      _ => status == 'completed' || status == 'cancelled',
    };
  }

  String _money(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();

    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 &&
          (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(digits[index]);
    }

    return 'Rs. ${negative ? '-' : ''}${buffer.toString()}';
  }

  DateTime? _requestTime(
    Map<String, dynamic> data,
  ) {
    final timestamp =
        data['completedAt'] as Timestamp? ??
            data['updatedAt'] as Timestamp? ??
            data['createdAt'] as Timestamp?;

    return timestamp?.toDate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RaScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: Text(
          'Job History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a provider to view your job history.',
              ),
            )
          : StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  RequestService().watchProviderRequests(),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load history',
                      message:
                          'Check your connection and try again.',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final history =
                    snapshot.data!.docs.where(
                  (request) {
                    final status =
                        request.data()['status']
                                as String? ??
                            '';

                    return status == 'completed' ||
                        status == 'cancelled';
                  },
                ).toList();

                history.sort(
                  (first, second) {
                    final firstTime =
                        _requestTime(first.data());

                    final secondTime =
                        _requestTime(second.data());

                    if (firstTime == null &&
                        secondTime == null) {
                      return 0;
                    }

                    if (firstTime == null) {
                      return 1;
                    }

                    if (secondTime == null) {
                      return -1;
                    }

                    return secondTime.compareTo(
                      firstTime,
                    );
                  },
                );

                final completed =
                    history.where(
                  (request) {
                    return request.data()['status'] ==
                        'completed';
                  },
                ).toList();

                final cancelled =
                    history.where(
                  (request) {
                    return request.data()['status'] ==
                        'cancelled';
                  },
                ).length;

                final revenue =
                    completed.fold<int>(
                  0,
                  (
                    total,
                    request,
                  ) {
                    final data =
                        request.data();

                    final amount =
                        (data['finalCost'] as num?)
                                ?.toInt() ??
                            (data['estimatedCost']
                                    as num?)
                                ?.toInt() ??
                            0;

                    return total + amount;
                  },
                );

                final filtered =
                    history.where(
                  (request) {
                    final status =
                        request.data()['status']
                                as String? ??
                            '';

                    return _matchesFilter(status);
                  },
                ).toList();

                return ListView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    32,
                  ),
                  children: [
                    _ProviderHistoryHero(
                      completed: completed.length,
                      cancelled: cancelled,
                      revenue: _money(revenue),
                    ),

                    const SizedBox(height: 18),

                    _ProviderHistoryFilters(
                      selected: filter,
                      labels: filters,
                      onChanged: (value) {
                        setState(() {
                          filter = value;
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            filter == 0
                                ? 'Completed & cancelled jobs'
                                : '${filters[filter]} jobs',
                            style:
                                GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing: -.25,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length}',
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 11),

                    if (filtered.isEmpty)
                      EmptyState(
                        icon: filter == 2
                            ? Icons.cancel_outlined
                            : Icons.history_rounded,
                        title: filter == 0
                            ? 'No job history yet'
                            : 'No ${filters[filter].toLowerCase()} jobs',
                        message: filter == 0
                            ? 'Completed and cancelled roadside jobs will appear here.'
                            : 'There are no jobs matching this filter.',
                      )
                    else
                      for (var index = 0;
                          index < filtered.length;
                          index++) ...[
                        if (index > 0)
                          const SizedBox(height: 9),

                        _ProviderHistoryCard(
                          requestId:
                              filtered[index].id,
                          data:
                              filtered[index].data(),
                          money: _money,
                        ),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

class _ProviderHistoryHero extends StatelessWidget {
  const _ProviderHistoryHero({
    required this.completed,
    required this.cancelled,
    required this.revenue,
  });

  final int completed;
  final int cancelled;
  final String revenue;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B477D),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'SERVICE HISTORY',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 8,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Your RoadAssist jobs',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _ProviderHistoryMetric(
                  value: '$completed',
                  label: 'Completed',
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ProviderHistoryMetric(
                  value: '$cancelled',
                  label: 'Cancelled',
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ProviderHistoryMetric(
                  value: revenue,
                  label: 'Revenue',
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderHistoryMetric extends StatelessWidget {
  const _ProviderHistoryMetric({
    required this.value,
    required this.label,
    this.compact = false,
  });

  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 66,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: .11,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: compact ? 9.5 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 7.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderHistoryFilters extends StatelessWidget {
  const _ProviderHistoryFilters({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest
            .withValues(alpha: .32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var index = 0;
              index < labels.length;
              index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right:
                      index == labels.length - 1
                          ? 0
                          : 4,
                ),
                child: Material(
                  color: selected == index
                      ? colors.primary
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      onChanged(index);
                    },
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        style:
                            GoogleFonts.plusJakartaSans(
                          fontSize: 8.6,
                          fontWeight:
                              FontWeight.w700,
                          color: selected == index
                              ? colors.onPrimary
                              : colors
                                  .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderHistoryCard extends StatelessWidget {
  const _ProviderHistoryCard({
    required this.requestId,
    required this.data,
    required this.money,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final String Function(int) money;

  String _location() {
    return data['locationLabel'] as String? ??
        data['location'] as String? ??
        'Location unavailable';
  }

  String _vehicle() {
    return [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ]
        .where(
          (value) =>
              value.trim().isNotEmpty,
        )
        .join(' • ');
  }

  String _date() {
    final timestamp =
        data['completedAt'] as Timestamp? ??
            data['updatedAt'] as Timestamp? ??
            data['createdAt'] as Timestamp?;

    final date =
        timestamp?.toDate().toLocal();

    if (date == null) {
      return 'Date unavailable';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status =
        data['status'] as String? ??
            'completed';

    final completed =
        status == 'completed';

    final driver =
        data['driverName'] as String? ??
            'Driver';

    final vehicle = _vehicle();

    final amount =
        (data['finalCost'] as num?)
                ?.toInt() ??
            (data['estimatedCost'] as num?)
                ?.toInt() ??
            0;

    final cancellationReason =
        data['cancellationReason'] as String? ?? '';

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          push(
            context,
            ProviderRequestDetailsScreen(
              requestId: requestId,
              data: data,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProfileInitials(
                    name: driver,
                    radius: 21,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          requestIssueLabel(data),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 8.4,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  StatusPill(
                    label: completed
                        ? 'Completed'
                        : 'Cancelled',
                    tone: completed
                        ? RaTone.success
                        : RaTone.danger,
                  ),
                ],
              ),

              const SizedBox(height: 13),

              _ProviderHistoryInfo(
                icon:
                    Icons.calendar_today_outlined,
                value: _date(),
              ),

              if (vehicle.isNotEmpty)
                _ProviderHistoryInfo(
                  icon:
                      Icons.directions_car_outlined,
                  value: vehicle,
                ),

              _ProviderHistoryInfo(
                icon:
                    Icons.location_on_outlined,
                value: _location(),
              ),

              if (!completed &&
                  cancellationReason.trim().isNotEmpty)
                _ProviderHistoryInfo(
                  icon:
                      Icons.info_outline_rounded,
                  value: cancellationReason,
                ),

              const SizedBox(height: 7),

              Divider(
                height: 1,
                color: colors.outlineVariant
                    .withValues(alpha: .35),
              ),

              const SizedBox(height: 11),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed
                              ? 'FINAL TOTAL'
                              : 'REQUEST TOTAL',
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 7.2,
                            fontWeight:
                                FontWeight.w700,
                            letterSpacing: .55,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          amount > 0
                              ? money(amount)
                              : 'Not recorded',
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  OutlinedButton.icon(
                    onPressed: () {
                      push(
                        context,
                        ProviderRequestDetailsScreen(
                          requestId: requestId,
                          data: data,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons
                          .arrow_forward_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Details',
                    ),
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

class _ProviderHistoryInfo extends StatelessWidget {
  const _ProviderHistoryInfo({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 15,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8.7,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}