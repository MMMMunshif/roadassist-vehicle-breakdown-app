part of '../../screens.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({
    super.key,
    required this.draft,
  });

  final RequestDraft draft;

  @override
  State<ProvidersScreen> createState() =>
      _ProvidersScreenState();
}

double? _providerDistanceKm(
  Map<String, dynamic> data,
  RequestDraft draft,
) {
  final latitude =
      (data['latitude'] as num?)
          ?.toDouble();

  final longitude =
      (data['longitude'] as num?)
          ?.toDouble();

  if (latitude == null ||
      longitude == null) {
    return null;
  }

  return Geolocator.distanceBetween(
        draft.latitude,
        draft.longitude,
        latitude,
        longitude,
      ) /
      1000;
}

String _providerAvailabilityStatus(
  Map<String, dynamic> data,
) {
  return ProviderAvailability.status(
    data,
    DateTime.now(),
    overrideUntil:
        (data['hoursOverrideUntil']
                as Timestamp?)
            ?.toDate(),
  );
}

bool _providerLocationOutdated(
  Map<String, dynamic> data,
) {
  final updated =
      (data['locationUpdatedAt']
              as Timestamp?)
          ?.toDate();

  return updated == null ||
      DateTime.now().difference(updated) >
          const Duration(minutes: 10);
}

bool _providerMatchesDraft(
  Map<String, dynamic> data,
  RequestDraft draft,
) {
  if (!_providerHasCurrentVerification(
        data,
      ) ||
      _providerAvailabilityStatus(
            data,
          ) !=
          'Online') {
    return false;
  }

  final vehicles =
      data['vehicleTypes'] as List? ??
          [];

  if (!vehicles.contains(
    draft.vehicleType,
  )) {
    return false;
  }

  if ((data['activeRequestId']
              as String? ??
          '')
      .isNotEmpty) {
    return false;
  }

  final services =
      (data['services']
                  as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toList();

  if (services.isNotEmpty &&
      !draft.issues.every(
        (issue) =>
            services.contains(issue),
      )) {
    return false;
  }

  final distanceKm =
      _providerDistanceKm(
    data,
    draft,
  );

  if (distanceKm == null) {
    return true;
  }

  final radiusText =
      data['serviceRadius']
              as String? ??
          '15 km';

  final radius = double.tryParse(
        RegExp(r'\d+')
                .firstMatch(radiusText)
                ?.group(0) ??
            '',
      ) ??
      15;

  return distanceKm <= radius;
}

class _ProvidersScreenState
    extends State<ProvidersScreen> {
  Timer? availabilityClock;

  late final Stream<
          QuerySnapshot<
              Map<String, dynamic>>>
      onlineProviders;

  String? selectedId;
  String? selectedName;

  @override
  void initState() {
    super.initState();

    availabilityClock =
        Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );

    onlineProviders =
        AuthService()
            .watchOnlineProviders();

    selectedId = widget
            .draft
            .preferredProviderId
            .isEmpty
        ? null
        : widget
            .draft.preferredProviderId;

    selectedName =
        widget.draft.provider.isEmpty
            ? null
            : widget.draft.provider;
  }

  @override
  void dispose() {
    availabilityClock?.cancel();
    super.dispose();
  }

  Future<void> reviewRequest() async {
    final selectedDraft =
        widget.draft.copyWith(
      provider: selectedName ??
          'Available Provider',
      preferredProviderId:
          selectedId,
    );

    await RequestDraftStore().save(
      selectedDraft,
    );

    if (!mounted) return;

    push(
      context,
      ReviewScreen(
        draft: selectedDraft,
      ),
    );
  }

  void scheduleProviderSelection(
    String? id,
    String? name,
  ) {
    if (selectedId == id &&
        selectedName == name) {
      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        selectedId = id;
        selectedName = name;
      });
    });
  }

  void selectAllOffers() {
    setState(() {
      selectedId = null;
      selectedName = null;
    });
  }

  Widget _buildProgress(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  999,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .looks_3_outlined,
                    size: 16,
                    color: colors
                        .onPrimaryContainer,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    'STEP 3 OF 4',
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: colors
                          .onPrimaryContainer,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          .8,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Providers',
              style: theme
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                color: colors.primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: RaSpace.sm,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .75,
            minHeight: 6,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSummary(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors
            .primaryContainer
            .withValues(alpha: .28),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              Icons
                  .location_on_outlined,
              color: colors
                  .onPrimaryContainer,
            ),
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
                  'Breakdown location',
                  style: theme
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  widget.draft.location,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: _NearbyProvidersMap(
        providers:
            onlineProviders,
        draft: widget.draft,
        selectedId: selectedId,
      ),
    );
  }

  Widget _buildAllOffersCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final selected =
        selectedId == null;

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer
                .withValues(alpha: .5)
            : colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? colors.primary
                  .withValues(alpha: .55)
              : colors.outlineVariant
                  .withValues(alpha: .6),
          width: selected
              ? 1.5
              : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(20),
        clipBehavior:
            Clip.antiAlias,
        child: InkWell(
          onTap: selectAllOffers,
          child: Padding(
            padding:
                const EdgeInsets.all(
              RaSpace.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                      BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors
                            .primaryContainer,
                    borderRadius:
                        BorderRadius
                            .circular(17),
                  ),
                  child: Icon(
                    Icons
                        .compare_arrows_rounded,
                    color: selected
                        ? colors.onPrimary
                        : colors
                            .onPrimaryContainer,
                    size: 26,
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
                        'Receive multiple offers',
                        style: theme
                            .textTheme
                            .titleMedium
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
                        'Suitable providers can review your request. Compare their price and service details before choosing one.',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: RaSpace.sm,
                ),

                Icon(
                  selected
                      ? Icons
                          .check_circle_rounded
                      : Icons
                          .radio_button_unchecked_rounded,
                  color: selected
                      ? colors.primary
                      : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
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
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title:
            const Text(
          'Choose Provider',
        ),
      ),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  RaSpace.lg,
                  RaSpace.sm,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  _buildProgress(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  Text(
                    'Choose how you want help',
                    style: theme
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Request offers from suitable providers or choose a specific available provider.',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  _buildLocationSummary(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildMap(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xl,
                  ),

                  _buildAllOffersCard(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Available providers',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              'Only currently suitable providers are shown.',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  StreamBuilder<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        onlineProviders,
                    builder:
                        (
                      context,
                      snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons
                              .cloud_off_outlined,
                          title:
                              'Unable to load providers',
                          message:
                              'Check your connection and try again.',
                        );
                      }

                      if (!snapshot.hasData) {
                        return const _RaProvidersLoading();
                      }

                      final providers =
                          snapshot.data!.docs
                              .where(
                        (provider) {
                          return _providerMatchesDraft(
                            provider.data(),
                            widget.draft,
                          );
                        },
                      ).toList();

                      providers.sort(
                        (a, b) {
                          final distanceA =
                              _providerDistanceKm(
                                    a.data(),
                                    widget.draft,
                                  ) ??
                                  double
                                      .infinity;

                          final distanceB =
                              _providerDistanceKm(
                                    b.data(),
                                    widget.draft,
                                  ) ??
                                  double
                                      .infinity;

                          return distanceA
                              .compareTo(
                            distanceB,
                          );
                        },
                      );

                      if (selectedId !=
                              null &&
                          !providers.any(
                            (provider) =>
                                provider.id ==
                                selectedId,
                          )) {
                        scheduleProviderSelection(
                          null,
                          null,
                        );
                      }

                      if (providers.isEmpty) {
                        return Container(
                          padding:
                              const EdgeInsets
                                  .all(
                            RaSpace.lg,
                          ),
                          decoration:
                              BoxDecoration(
                            color: colors
                                .surface,
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
                          child: Column(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration:
                                    BoxDecoration(
                                  color: colors
                                      .surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .person_search_outlined,
                                  color: colors
                                      .primary,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(
                                height:
                                    RaSpace
                                        .md,
                              ),
                              Text(
                                'No matching providers online right now',
                                textAlign:
                                    TextAlign
                                        .center,
                                style: theme
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'You can still continue with the multiple-offer option. Suitable providers may respond when your request becomes available.',
                                textAlign:
                                    TextAlign
                                        .center,
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  height:
                                      1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (var index = 0;
                              index <
                                  providers
                                      .length;
                              index++) ...[
                            _RaPremiumProviderCard(
                              providerId:
                                  providers[
                                          index]
                                      .id,
                              data:
                                  providers[
                                          index]
                                      .data(),
                              draft:
                                  widget
                                      .draft,
                              selected:
                                  selectedId ==
                                      providers[
                                              index]
                                          .id,
                              onTap: () {
                                final data =
                                    providers[index]
                                        .data();

                                setState(
                                  () {
                                    selectedId =
                                        providers[index]
                                            .id;

                                    selectedName =
                                        data['displayName']
                                                as String? ??
                                            'Service Provider';
                                  },
                                );
                              },
                            ),
                            if (index !=
                                providers
                                        .length -
                                    1)
                              const SizedBox(
                                height:
                                    RaSpace
                                        .sm,
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            _RaProvidersBottomBar(
              selectedProvider:
                  selectedName,
              onContinue:
                  reviewRequest,
            ),
          ],
        ),
      ),
    );
  }
}

class _RaPremiumProviderCard
    extends StatelessWidget {
  const _RaPremiumProviderCard({
    required this.providerId,
    required this.data,
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  final String providerId;
  final Map<String, dynamic> data;
  final RequestDraft draft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final name =
        data['displayName']
                as String? ??
            'Service Provider';

    final distance =
        _providerDistanceKm(
      data,
      draft,
    );

    final stale =
        _providerLocationOutdated(
      data,
    );

    final rating =
        (data['averageRating']
                as num?)
            ?.toDouble();

    final completedJobs =
        (data['completedJobs']
                as num?)
            ?.toInt();

    final responseMinutes =
        (data['averageResponseMinutes']
                as num?)
            ?.toDouble();

    final services =
        (data['services']
                    as List<dynamic>? ??
                const [])
            .whereType<String>()
            .toList();

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer
                .withValues(alpha: .42)
            : colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? colors.primary
                  .withValues(alpha: .55)
              : colors.outlineVariant
                  .withValues(alpha: .6),
          width: selected
              ? 1.5
              : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.primary
                      .withValues(
                    alpha: .08,
                  ),
                  blurRadius: 18,
                  offset:
                      const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(22),
        clipBehavior:
            Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.all(
              RaSpace.lg,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    ProfileInitials(
                      name: name,
                      radius: 27,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines:
                                      1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style: theme
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width:
                                    RaSpace
                                        .sm,
                              ),
                              Icon(
                                selected
                                    ? Icons
                                        .check_circle_rounded
                                    : Icons
                                        .radio_button_unchecked_rounded,
                                color: selected
                                    ? colors
                                        .primary
                                    : colors
                                        .outline,
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              const _RaProviderMiniChip(
                                icon: Icons
                                    .verified_outlined,
                                label:
                                    'Verified',
                              ),
                              const _RaProviderMiniChip(
                                icon: Icons
                                    .circle,
                                label:
                                    'Online',
                                success:
                                    true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Wrap(
                  spacing: RaSpace.sm,
                  runSpacing: RaSpace.sm,
                  children: [
                    _RaProviderStat(
                      icon: Icons
                          .location_on_outlined,
                      value: stale
                          ? 'Location needs confirmation'
                          : distance == null
                              ? 'Distance unavailable'
                              : '${distance.toStringAsFixed(1)} km away',
                    ),

                    if (responseMinutes !=
                            null &&
                        responseMinutes > 0)
                      _RaProviderStat(
                        icon: Icons
                            .schedule_outlined,
                        value:
                            '${responseMinutes.ceil()} min avg. response',
                      ),

                    if (rating !=
                            null &&
                        rating > 0)
                      _RaProviderStat(
                        icon: Icons
                            .star_outline_rounded,
                        value:
                            '${rating.toStringAsFixed(1)} rating',
                      ),

                    if (completedJobs !=
                            null &&
                        completedJobs > 0)
                      _RaProviderStat(
                        icon: Icons
                            .task_alt_rounded,
                        value:
                            '$completedJobs completed',
                      ),
                  ],
                ),

                if (services.isNotEmpty) ...[
                  const SizedBox(
                    height: RaSpace.md,
                  ),

                  Text(
                    'Services',
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final service
                          in services.take(3))
                        Chip(
                          visualDensity:
                              VisualDensity
                                  .compact,
                          label: Text(
                            service,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                      if (services.length >
                          3)
                        Chip(
                          visualDensity:
                              VisualDensity
                                  .compact,
                          label: Text(
                            '+${services.length - 3}',
                          ),
                        ),
                    ],
                  ),
                ],

                if (stale) ...[
                  const SizedBox(
                    height: RaSpace.md,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .all(
                      RaSpace.sm,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .tertiaryContainer
                          .withValues(
                        alpha: .38,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .location_searching_rounded,
                          size: 17,
                          color: colors
                              .onTertiaryContainer,
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        const Expanded(
                          child: Text(
                            'Provider location may be outdated. Confirm location after connecting.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaProviderMiniChip
    extends StatelessWidget {
  const _RaProviderMiniChip({
    required this.icon,
    required this.label,
    this.success = false,
  });

  final IconData icon;
  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final color = success
        ? raSuccess
        : colors.primary;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: .08),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
              color: color,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderStat
    extends StatelessWidget {
  const _RaProviderStat({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colors
              .onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

class _RaProvidersLoading
    extends StatelessWidget {
  const _RaProvidersLoading();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var index = 0;
            index < 3;
            index++) ...[
          Container(
            height: 175,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(
                alpha: .55,
              ),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
          ),
          if (index != 2)
            const SizedBox(
              height: RaSpace.sm,
            ),
        ],
      ],
    );
  }
}

class _RaProvidersBottomBar
    extends StatelessWidget {
  const _RaProvidersBottomBar({
    required this.selectedProvider,
    required this.onContinue,
  });

  final String? selectedProvider;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final provider =
        selectedProvider;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        RaSpace.lg,
        RaSpace.sm,
        RaSpace.lg,
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors
                .outlineVariant
                .withValues(alpha: .6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: .04),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  provider == null
                      ? Icons
                          .compare_arrows_rounded
                      : Icons
                          .person_outline_rounded,
                  color:
                      colors.primary,
                  size: 17,
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child: Text(
                    provider == null
                        ? 'Multiple provider offers selected'
                        : 'Selected: $provider',
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
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
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  FilledButton.icon(
                onPressed:
                    onContinue,
                icon: const Icon(
                  Icons
                      .arrow_forward_rounded,
                ),
                label: const Text(
                  'Review Request',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}