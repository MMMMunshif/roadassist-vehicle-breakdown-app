part of '../../screens.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}

class _HistoryScreenState
    extends State<HistoryScreen> {
  int filter = 0;

  static const activeStatuses = <String>{
    'searching',
    'accepted',
    'en_route',
    'arrived',
  };

  bool matchesFilter(String status) {
    return switch (filter) {
      1 => activeStatuses.contains(status),
      2 => status == 'completed',
      3 => status == 'cancelled',
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text(
          'Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              push(
                context,
                const DriverNotificationsScreen(),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              onPressed: () {
                push(
                  context,
                  const AssistanceTypeScreen(),
                );
              },
              icon: const Icon(
                Icons.add_road_rounded,
              ),
              label: const Text(
                'New request',
              ),
            )
          : null,
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a driver to view your assistance requests.',
              ),
            )
          : StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
              stream: RequestService()
                  .watchDriverRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyState(
                      icon:
                          Icons.cloud_off_outlined,
                      title:
                          'Unable to load requests',
                      message:
                          'Check your connection and try again.',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const _PremiumDriverHistoryLoadingView();
                }

                final allRequests =
                    [...snapshot.data!.docs];

                allRequests.sort((a, b) {
                  final aTime =
                      a.data()['createdAt']
                          as Timestamp?;

                  final bTime =
                      b.data()['createdAt']
                          as Timestamp?;

                  if (aTime == null &&
                      bTime == null) {
                    return 0;
                  }

                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });

                final activeCount =
                    allRequests.where((request) {
                  final status =
                      request.data()['status']
                              as String? ??
                          '';

                  return activeStatuses.contains(
                    status,
                  );
                }).length;

                final completedCount =
                    allRequests.where((request) {
                  return request.data()['status'] ==
                      'completed';
                }).length;

                final cancelledCount =
                    allRequests.where((request) {
                  return request.data()['status'] ==
                      'cancelled';
                }).length;

                final filtered =
                    allRequests.where((request) {
                  return matchesFilter(
                    request.data()['status']
                            as String? ??
                        '',
                  );
                }).toList();

                return ListView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    100,
                  ),
                  children: [
                    _PremiumDriverRequestsOverview(
                      total:
                          allRequests.length,
                      active: activeCount,
                      completed:
                          completedCount,
                    ),

                    const SizedBox(height: 27),

                    Text(
                      'Your assistance',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -.4,
                        color:
                            colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Track current roadside help and revisit previous service requests.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        height: 1.45,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 17),

                    _PremiumDriverRequestFilterBar(
                      selected: filter,
                      onSelected: (value) {
                        setState(() {
                          filter = value;
                        });
                      },
                    ),

                    const SizedBox(height: 17),

                    if (filtered.isEmpty)
                      _PremiumDriverHistoryEmptyState(
                        filter: filter,
                      )
                    else
                      for (var i = 0;
                          i < filtered.length;
                          i++) ...[
                        _PremiumDriverHistoryCard(
                          requestId:
                              filtered[i].id,
                          data:
                              filtered[i].data(),
                        ),
                        if (i !=
                            filtered.length - 1)
                          const SizedBox(
                            height: 11,
                          ),
                      ],

                    if (cancelledCount > 0 &&
                        filter == 0) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        decoration: BoxDecoration(
                          color: colors
                              .surfaceContainerHighest
                              .withValues(
                            alpha: .36,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 17,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(
                              width: 9,
                            ),
                            Expanded(
                              child: Text(
                                'Cancelled requests remain available for your records.',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize: 10.5,
                                  height: 1.4,
                                  color: colors
                                      .onSurfaceVariant,
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

class _PremiumDriverRequestsOverview
    extends StatelessWidget {
  const _PremiumDriverRequestsOverview({
    required this.total,
    required this.active,
    required this.completed,
  });

  final int total;
  final int active;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final start = dark
        ? const Color(0xFF0B477E)
        : const Color(0xFF075BA8);

    final end = dark
        ? const Color(0xFF08645E)
        : const Color(0xFF078F80);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(25),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        boxShadow: [
          BoxShadow(
            color:
                start.withValues(alpha: .20),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: .12),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons
                      .receipt_long_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 11),

              Text(
                'REQUEST OVERVIEW',
                style:
                    GoogleFonts.plusJakartaSans(
                  color: Colors.white
                      .withValues(alpha: .76),
                  fontSize: 9,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Text(
            active > 0
                ? '$active active ${active == 1 ? 'request' : 'requests'}'
                : 'You’re all clear',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.65,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            active > 0
                ? 'Your roadside assistance is still in progress.'
                : 'No roadside assistance is currently active.',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white
                  .withValues(alpha: .80),
              fontSize: 10.8,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child:
                    _PremiumDriverRequestMetric(
                  value: '$active',
                  label: 'Active',
                  icon:
                      Icons.route_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _PremiumDriverRequestMetric(
                  value: '$completed',
                  label: 'Completed',
                  icon: Icons
                      .check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _PremiumDriverRequestMetric(
                  value: '$total',
                  label: 'Total',
                  icon: Icons
                      .history_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumDriverRequestMetric
    extends StatelessWidget {
  const _PremiumDriverRequestMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(minHeight: 78),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: .10),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: .10),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style:
                  GoogleFonts.plusJakartaSans(
                color: Colors.white
                    .withValues(alpha: .72),
                fontSize: 8.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDriverRequestFilterBar
    extends StatelessWidget {
  const _PremiumDriverRequestFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const filters = [
    ('All', Icons.apps_rounded),
    ('Active', Icons.route_outlined),
    (
      'Completed',
      Icons.check_circle_outline_rounded
    ),
    (
      'Cancelled',
      Icons.cancel_outlined
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics:
          const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0;
              i < filters.length;
              i++) ...[
            if (i != 0)
              const SizedBox(width: 8),

            ChoiceChip(
              selected: selected == i,
              onSelected: (_) {
                onSelected(i);
              },
              avatar: Icon(
                filters[i].$2,
                size: 16,
                color: selected == i
                    ? colors.onPrimary
                    : colors
                        .onSurfaceVariant,
              ),
              label: Text(
                filters[i].$1,
              ),
              labelStyle:
                  GoogleFonts.plusJakartaSans(
                color: selected == i
                    ? colors.onPrimary
                    : colors
                        .onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
              selectedColor:
                  colors.primary,
              backgroundColor:
                  colors.surface,
              side: BorderSide(
                color: selected == i
                    ? colors.primary
                    : colors.outlineVariant
                        .withValues(
                        alpha: .55,
                      ),
              ),
              shape:
                  const StadiumBorder(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumDriverHistoryCard
    extends StatelessWidget {
  const _PremiumDriverHistoryCard({
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    final status =
        data['status'] as String? ??
            'searching';

    final active = const [
      'searching',
      'accepted',
      'en_route',
      'arrived',
    ].contains(status);

    final draft =
        requestDraftFromData(data);

    final provider =
        data['providerName'] as String? ??
            (status == 'searching'
                ? 'Finding a provider'
                : 'Not assigned');

    final statusLabel = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };

    final tone = switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      _ => RaTone.info,
    };

    final created =
        (data['createdAt'] as Timestamp?)
            ?.toDate()
            .toLocal();

    final date = created == null
        ? 'Date unavailable'
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';

    final registration =
        data['registration']
                as String? ??
            '';

    final vehicle =
        data['modelYear'] as String? ??
            data['vehicleType']
                as String? ??
            '';

    final rawCost =
        data['finalCost'] ??
            data['estimatedCost'];

    final cost = rawCost is num
        ? 'Rs. ${rawCost.toInt()}'
        : 'Not quoted yet';

    void continueRequest() {
      if (status == 'searching') {
        push(
          context,
          SearchingScreen(
            draft: draft,
            requestId: requestId,
          ),
        );

        return;
      }

      push(
        context,
        TrackingScreen(
          draft: draft,
          requestId: requestId,
        ),
      );
    }

    Future<void>
        cancelActiveRequest() async {
      final confirmed =
          await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: raDanger
                    .withValues(alpha: .10),
                borderRadius:
                    BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons
                    .warning_amber_rounded,
                color: raDanger,
              ),
            ),
            title: const Text(
              'Cancel current request?',
            ),
            content: const Text(
              'The active assistance request will stop and remain in your cancelled history.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text(
                  'Keep Request',
                ),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      raDanger,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'Cancel Request',
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true ||
          !context.mounted) {
        return;
      }

      try {
        await RequestService()
            .cancelRequest(requestId);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Assistance request cancelled.',
            ),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to cancel this request.',
            ),
          ),
        );
      }
    }

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(21),
          border: Border.all(
            color: colors.outlineVariant
                .withValues(alpha: .50),
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    date.toUpperCase(),
                    style: GoogleFonts
                        .plusJakartaSans(
                      color: colors
                          .onSurfaceVariant,
                      fontSize: 8.5,
                      letterSpacing: .8,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  StatusPill(
                    label: statusLabel,
                    tone: tone,
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration:
                        BoxDecoration(
                      color: colors.primary
                          .withValues(
                        alpha: .09,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(14),
                    ),
                    child: Icon(
                      Icons
                          .car_repair_outlined,
                      color:
                          colors.primary,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          requestIssueLabel(
                            data,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow
                              .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight:
                                FontWeight.w700,
                            color: colors
                                .onSurface,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          provider,
                          maxLines: 1,
                          overflow: TextOverflow
                              .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 10.5,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Divider(
                height: 1,
                color: colors.outlineVariant
                    .withValues(alpha: .40),
              ),

              const SizedBox(height: 12),

              _PremiumRequestInfoRow(
                icon:
                    Icons.directions_car_outlined,
                label: 'Vehicle',
                value: vehicle.trim().isEmpty
                    ? 'Not provided'
                    : vehicle,
              ),

              if (registration
                  .trim()
                  .isNotEmpty)
                _PremiumRequestInfoRow(
                  icon: Icons
                      .pin_outlined,
                  label: 'Registration',
                  value: registration,
                ),

              _PremiumRequestInfoRow(
                icon: Icons
                    .location_on_outlined,
                label: 'Location',
                value:
                    data['locationLabel']
                            as String? ??
                        data['location']
                            as String? ??
                        'Pinned location',
              ),

              _PremiumRequestInfoRow(
                icon:
                    Icons.payments_outlined,
                label: status == 'completed'
                    ? 'Final cost'
                    : 'Current estimate',
                value: cost,
                strong: true,
              ),

              if (data['driverRating'] !=
                  null)
                _PremiumRequestInfoRow(
                  icon:
                      Icons.star_rounded,
                  label: 'Your rating',
                  value:
                      '${data['driverRating']} / 5',
                ),

              const SizedBox(height: 12),

              if (active) ...[
                Row(
                  children: [
                    Expanded(
                      child:
                          FilledButton.icon(
                        onPressed:
                            continueRequest,
                        icon: Icon(
                          status ==
                                  'searching'
                              ? Icons
                                  .search_rounded
                              : Icons
                                  .near_me_rounded,
                        ),
                        label: Text(
                          status ==
                                  'searching'
                              ? 'Search'
                              : 'Continue',
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    SizedBox(
                      width: 52,
                      height: 52,
                      child:
                          OutlinedButton(
                        style: OutlinedButton
                            .styleFrom(
                          padding:
                              EdgeInsets.zero,
                          foregroundColor:
                              raDanger,
                        ),
                        onPressed:
                            cancelActiveRequest,
                        child: const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    push(
                      context,
                      RealtimeDriverRequestDetailsScreen(
                        requestId:
                            requestId,
                        data: data,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons
                        .receipt_long_outlined,
                    size: 17,
                  ),
                  label: const Text(
                    'View Request Details',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumRequestInfoRow
    extends StatelessWidget {
  const _PremiumRequestInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                colors.onSurfaceVariant,
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 84,
            child: Text(
              label,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 9.5,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.plusJakartaSans(
                color: strong
                    ? colors.primary
                    : colors.onSurface,
                fontSize: 10.5,
                height: 1.35,
                fontWeight: strong
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDriverHistoryEmptyState
    extends StatelessWidget {
  const _PremiumDriverHistoryEmptyState({
    required this.filter,
  });

  final int filter;

  @override
  Widget build(BuildContext context) {
    final result = switch (filter) {
      1 => (
          Icons.route_outlined,
          'No active requests',
          'You do not have roadside assistance in progress.'
        ),
      2 => (
          Icons
              .check_circle_outline_rounded,
          'No completed requests',
          'Completed services will appear here.'
        ),
      3 => (
          Icons.cancel_outlined,
          'No cancelled requests',
          'Cancelled requests will appear here.'
        ),
      _ => (
          Icons
              .receipt_long_outlined,
          'No requests yet',
          'Your roadside assistance history will appear here.'
        ),
    };

    return Padding(
      padding:
          const EdgeInsets.only(top: 16),
      child: EmptyState(
        icon: result.$1,
        title: result.$2,
        message: result.$3,
      ),
    );
  }
}

class _PremiumDriverHistoryLoadingView
    extends StatelessWidget {
  const _PremiumDriverHistoryLoadingView();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: colors
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(25),
          ),
        ),
        const SizedBox(height: 25),
        for (var i = 0;
            i < 3;
            i++) ...[
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(21),
              border: Border.all(
                color:
                    colors.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}