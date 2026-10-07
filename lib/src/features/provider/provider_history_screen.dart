part of '../../screens.dart';

class ProviderHistoryScreen
    extends StatefulWidget {
  const ProviderHistoryScreen({
    super.key,
  });

  @override
  State<ProviderHistoryScreen>
      createState() =>
          _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState
    extends State<ProviderHistoryScreen> {
  int filter = 0;

  String _date(
    Map<String, dynamic> data,
  ) {
    final created =
        (data['createdAt']
                as Timestamp?)
            ?.toDate()
            .toLocal();

    if (created == null) {
      return 'Date unavailable';
    }

    return '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} • ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  }

  Widget _filterChip(
    String label,
    int value,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected:
          filter == value,
      onSelected: (_) {
        setState(() {
          filter = value;
        });
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        title:
            const Text(
          'Job History',
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: RequestService()
            .watchProviderRequests(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons
                  .cloud_off_outlined,
              title:
                  'Unable to load history',
              message:
                  'Check your connection and try again.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final all =
              snapshot.data!.docs
                  .where(
            (job) {
              final status =
                  job.data()[
                          'status']
                      as String? ??
                      '';

              return status ==
                      'completed' ||
                  status ==
                      'cancelled' ||
                  status ==
                      'rejected';
            },
          ).toList();

          all.sort(
            (a, b) {
              final at =
                  (a.data()[
                              'createdAt']
                          as Timestamp?)
                      ?.toDate();

              final bt =
                  (b.data()[
                              'createdAt']
                          as Timestamp?)
                      ?.toDate();

              if (at == null ||
                  bt == null) {
                return 0;
              }

              return bt
                  .compareTo(at);
            },
          );

          final completedCount =
              all
                  .where(
                    (job) =>
                        job.data()[
                            'status'] ==
                        'completed',
                  )
                  .length;

          final cancelledCount =
              all.length -
                  completedCount;

          final jobs =
              all.where(
            (job) {
              final status =
                  job.data()[
                          'status']
                      as String? ??
                      '';

              if (filter == 1) {
                return status ==
                    'completed';
              }

              if (filter == 2) {
                return status ==
                        'cancelled' ||
                    status ==
                        'rejected';
              }

              return true;
            },
          ).toList();

          return ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              RaSpace.xxxl,
            ),
            children: [
              Container(
                padding:
                    const EdgeInsets
                        .all(
                  RaSpace.xl,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment
                            .topLeft,
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
                      BorderRadius
                          .circular(
                    24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Your service history',
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      'Review completed, cancelled and declined provider jobs.',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .82,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child:
                              _ProviderHistoryMetric(
                            value:
                                '$completedCount',
                            label:
                                'Completed',
                          ),
                        ),
                        const SizedBox(
                          width:
                              RaSpace.sm,
                        ),
                        Expanded(
                          child:
                              _ProviderHistoryMetric(
                            value:
                                '$cancelledCount',
                            label:
                                'Cancelled',
                          ),
                        ),
                        const SizedBox(
                          width:
                              RaSpace.sm,
                        ),
                        Expanded(
                          child:
                              _ProviderHistoryMetric(
                            value:
                                '${all.length}',
                            label:
                                'Total',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      'All',
                      0,
                    ),
                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    _filterChip(
                      'Completed',
                      1,
                    ),
                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    _filterChip(
                      'Cancelled',
                      2,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              if (jobs.isEmpty)
                EmptyState(
                  icon: Icons
                      .history_outlined,
                  title: filter == 0
                      ? 'No job history'
                      : filter == 1
                          ? 'No completed jobs'
                          : 'No cancelled jobs',
                  message:
                      'Matching provider jobs will appear here automatically.',
                )
              else
                for (var index = 0;
                    index <
                        jobs.length;
                    index++) ...[
                  Builder(
                    builder: (
                      context,
                    ) {
                      final job =
                          jobs[index];

                      final data =
                          job.data();

                      final vehicle = [
                        data[
                            'modelYear'],
                        data[
                            'registration'],
                      ]
                          .whereType<
                              String>()
                          .where(
                            (value) =>
                                value
                                    .trim()
                                    .isNotEmpty,
                          )
                          .join(
                            ' - ',
                          );

                      final completed =
                          data['status'] ==
                              'completed';

                      final statusColor =
                          completed
                              ? raSuccess
                              : colors
                                  .error;

                      return Material(
                        color: colors
                            .surface,
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                        clipBehavior:
                            Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              push(
                            context,
                            ProviderRequestDetailsScreen(
                              requestId:
                                  job.id,
                              data:
                                  data,
                            ),
                          ),
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .all(
                              RaSpace
                                  .lg,
                            ),
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                              border:
                                  Border.all(
                                color: colors
                                    .outlineVariant
                                    .withValues(
                                  alpha:
                                      .6,
                                ),
                              ),
                            ),
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    ProfileInitials(
                                      name: data['driverName']
                                              as String? ??
                                          'Driver',
                                      radius:
                                          23,
                                    ),
                                    const SizedBox(
                                      width:
                                          RaSpace
                                              .md,
                                    ),
                                    Expanded(
                                      child:
                                          Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['driverName']
                                                    as String? ??
                                                'Driver',
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: theme
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                2,
                                          ),
                                          Text(
                                            _date(
                                              data,
                                            ),
                                            style: theme
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal:
                                            8,
                                        vertical:
                                            5,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: statusColor
                                            .withValues(
                                          alpha:
                                              .09,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child:
                                          Text(
                                        completed
                                            ? 'COMPLETED'
                                            : 'CANCELLED',
                                        style: theme
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          color:
                                              statusColor,
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height:
                                      RaSpace
                                          .md,
                                ),

                                _ProviderHistoryLine(
                                  icon:
                                      Icons.car_repair_outlined,
                                  value:
                                      requestIssueLabel(
                                    data,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      RaSpace
                                          .sm,
                                ),

                                _ProviderHistoryLine(
                                  icon:
                                      Icons.directions_car_outlined,
                                  value: vehicle.isEmpty
                                      ? data['vehicleType']
                                              as String? ??
                                          'Vehicle'
                                      : vehicle,
                                ),

                                const SizedBox(
                                  height:
                                      RaSpace
                                          .sm,
                                ),

                                _ProviderHistoryLine(
                                  icon:
                                      Icons.location_on_outlined,
                                  value:
                                      data['locationLabel']
                                              as String? ??
                                          'Pinned location',
                                ),

                                const SizedBox(
                                  height:
                                      RaSpace
                                          .md,
                                ),

                                Row(
                                  children: [
                                    if (completed)
                                      Expanded(
                                        child:
                                            Text(
                                          'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                                          style: theme
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                            color:
                                                colors.primary,
                                            fontWeight:
                                                FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    Text(
                                      'View details',
                                      style: theme
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                        color:
                                            colors.primary,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                    Icon(
                                      Icons
                                          .chevron_right_rounded,
                                      color:
                                          colors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (index !=
                      jobs.length - 1)
                    const SizedBox(
                      height:
                          RaSpace.sm,
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ProviderHistoryMetric
    extends StatelessWidget {
  const _ProviderHistoryMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: .12,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white
                  .withValues(
                alpha: .74,
              ),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderHistoryLine
    extends StatelessWidget {
  const _ProviderHistoryLine({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color:
              colors.primary,
        ),
        const SizedBox(
          width: RaSpace.sm,
        ),
        Expanded(
          child: Text(
            value,
            style:
                Theme.of(context)
                    .textTheme
                    .bodySmall,
          ),
        ),
      ],
    );
  }
}