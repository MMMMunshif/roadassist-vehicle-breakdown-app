part of '../../screens.dart';

class AdminJobMonitorScreen
    extends StatefulWidget {
  const AdminJobMonitorScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<AdminJobMonitorScreen>
      createState() =>
          _AdminJobMonitorScreenState();
}

class _AdminJobMonitorScreenState
    extends State<AdminJobMonitorScreen> {
  late final job =
      FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .snapshots();

  String formatDate(
    DateTime value,
  ) {
    final local = value.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Job Monitor',
        ),
      ),
      body: StreamBuilder<
        DocumentSnapshot<
          Map<String, dynamic>
        >
      >(
        stream: job,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons
                  .cloud_off_outlined,
              title:
                  'Unable to load job',
              message:
                  'Check your admin access and connection.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data();

          if (data == null) {
            return const EmptyState(
              icon: Icons
                  .search_off_outlined,
              title: 'Job not found',
              message:
                  'This assistance request is no longer available.',
            );
          }

          final status =
              data['status']
                      as String? ??
                  'unknown';

          final updated =
              (data['updatedAt']
                      as Timestamp?)
                  ?.toDate();

          final active = const [
            'accepted',
            'en_route',
            'arrived',
          ].contains(status);

          final stale =
              active &&
              updated != null &&
              DateTime.now()
                      .difference(updated)
                      .inMinutes >=
                  60;

          final latitude =
              (data['latitude']
                      as num?)
                  ?.toDouble();

          final longitude =
              (data['longitude']
                      as num?)
                  ?.toDouble();

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              RaSpace.xxxl,
            ),
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  RaSpace.xl,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end: Alignment
                        .bottomRight,
                    colors: status ==
                            'completed'
                        ? const [
                            raSuccess,
                            Color(
                              0xFF087064,
                            ),
                          ]
                        : status ==
                                'cancelled'
                            ? [
                                colors.error,
                                const Color(
                                  0xFF9A2922,
                                ),
                              ]
                            : [
                                colors.primary,
                                const Color(
                                  0xFF007D70,
                                ),
                              ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JOB ${widget.requestId}',
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha: .78,
                        ),
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: RaSpace.md,
                    ),
                    Text(
                      status
                          .replaceAll(
                            '_',
                            ' ',
                          )
                          .toUpperCase(),
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      requestIssueLabel(data),
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha: .84,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (stale) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                Container(
                  padding:
                      const EdgeInsets.all(
                    RaSpace.md,
                  ),
                  decoration:
                      BoxDecoration(
                    color: raGoldPale,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .schedule_outlined,
                        color: raGold,
                      ),
                      SizedBox(
                        width: RaSpace.sm,
                      ),
                      Expanded(
                        child: Text(
                          'No recorded update for at least one hour. Review the situation and contact participants if appropriate. This alert alone does not establish misconduct.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: RaSpace.xxl,
              ),

              Text(
                'Participants',
                style: theme
                    .textTheme.titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _AdminMonitorParticipant(
                title:
                    data['driverName']
                            as String? ??
                        'Driver',
                role: 'Driver',
                phone:
                    data['driverPhone']
                            as String? ??
                        '',
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              _AdminMonitorParticipant(
                title:
                    data['providerName']
                            as String? ??
                        'Unassigned',
                role: 'Provider',
                phone:
                    data['providerPhone']
                            as String? ??
                        '',
              ),

              if (active &&
                  data['providerId']
                      is String) ...[
                const SizedBox(
                  height: RaSpace.sm,
                ),
                StreamBuilder<
                  DocumentSnapshot<
                    Map<String, dynamic>
                  >
                >(
                  stream: FirebaseFirestore
                      .instance
                      .collection(
                        'providerDirectory',
                      )
                      .doc(
                        data['providerId']
                            as String,
                      )
                      .snapshots(),
                  builder: (
                    context,
                    presence,
                  ) {
                    if (!presence.hasData ||
                        presence.hasError) {
                      return const SizedBox
                          .shrink();
                    }

                    final online =
                        presence.data
                                    ?.data()?[
                                'online'] ==
                            true;

                    return Container(
                      padding:
                          const EdgeInsets
                              .all(
                        RaSpace.md,
                      ),
                      decoration:
                          BoxDecoration(
                        color: online
                            ? raSuccess
                                .withValues(
                                alpha: .08,
                              )
                            : raGold
                                .withValues(
                                alpha: .08,
                              ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            online
                                ? Icons
                                    .wifi_rounded
                                : Icons
                                    .wifi_off_rounded,
                            color: online
                                ? raSuccess
                                : raGold,
                          ),
                          const SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          Expanded(
                            child: Text(
                              online
                                  ? 'Assigned provider is currently online.'
                                  : 'Assigned provider is currently offline. Contact them if a job update is overdue.',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(
                height: RaSpace.xxl,
              ),

              Text(
                'Job information',
                style: theme
                    .textTheme.titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _AdminMonitorCard(
                children: [
                  _AdminMonitorRow(
                    label: 'Status',
                    value: status.replaceAll(
                      '_',
                      ' ',
                    ),
                  ),
                  _AdminMonitorRow(
                    label: 'Vehicle',
                    value:
                        data['modelYear']
                                as String? ??
                            'Not recorded',
                  ),
                  _AdminMonitorRow(
                    label: 'Problem',
                    value:
                        requestIssueLabel(
                      data,
                    ),
                  ),
                  _AdminMonitorRow(
                    label: 'Location',
                    value:
                        data['locationLabel']
                                as String? ??
                            'Not recorded',
                  ),
                  _AdminMonitorRow(
                    label:
                        'Approved amount',
                    value:
                        'Rs. ${data['estimatedCost'] ?? 0}',
                    strong: true,
                  ),
                  if (updated != null)
                    _AdminMonitorRow(
                      label:
                          'Last recorded update',
                      value:
                          formatDate(updated),
                    ),
                ],
              ),

              if (latitude != null &&
                  longitude != null) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  child: SizedBox(
                    height: 240,
                    child: MapMock(
                      position: LatLng(
                        latitude,
                        longitude,
                      ),
                    ),
                  ),
                ),
              ],

              if ((data['description']
                          as String? ??
                      '')
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                Container(
                  padding:
                      const EdgeInsets.all(
                    RaSpace.lg,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors.surface,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color: colors
                          .outlineVariant
                          .withValues(
                        alpha: .6,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver description',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: RaSpace.sm,
                      ),
                      Text(
                        data['description']
                            as String,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: RaSpace.lg,
              ),

              if (status == 'completed')
                SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed: () => push(
                      context,
                      InvoiceScreen(
                        requestId:
                            widget.requestId,
                      ),
                    ),
                    icon: const Icon(
                      Icons
                          .receipt_long_outlined,
                    ),
                    label: const Text(
                      'Review Invoice & Approvals',
                    ),
                  ),
                ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  RaSpace.md,
                ),
                decoration:
                    BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .4,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .visibility_outlined,
                      size: 19,
                    ),
                    SizedBox(
                      width: RaSpace.sm,
                    ),
                    Expanded(
                      child: Text(
                        'Job monitoring is read-only. Use the agreed support process to contact participants. Monitoring does not change assignment, price or job status.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminMonitorParticipant
    extends StatelessWidget {
  const _AdminMonitorParticipant({
    required this.title,
    required this.role,
    required this.phone,
  });

  final String title;
  final String role;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Row(
        children: [
          ProfileInitials(
            name: title,
            radius: 22,
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                Text(
                  role,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Call $role',
            onPressed: phone.isEmpty
                ? null
                : () => showCallPrompt(
                    context,
                    name: title,
                    number: phone,
                  ),
            icon: const Icon(
              Icons.call_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMonitorCard
    extends StatelessWidget {
  const _AdminMonitorCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _AdminMonitorRow
    extends StatelessWidget {
  const _AdminMonitorRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

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
        vertical: RaSpace.md,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme.bodySmall
                  ?.copyWith(
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style: Theme.of(context)
                  .textTheme.bodyMedium
                  ?.copyWith(
                fontWeight: strong
                    ? FontWeight.w900
                    : FontWeight.w700,
                color: strong
                    ? colors.primary
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}