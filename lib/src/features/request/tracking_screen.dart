part of '../../screens.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.draft,
    this.requestId,
  });

  final RequestDraft draft;
  final String? requestId;

  @override
  State<TrackingScreen> createState() =>
      _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  int status = 0;

  LatLng providerPosition =
      MapMock.providerPoint;

  String providerName =
      'Service Provider';

  String providerPhone = '';

  int estimatedCost = 0;

  bool cancelled = false;

  bool arrivalNeedsConfirmation =
      false;

  String arrivalLocationHint = '';

  bool completionPending = false;

  String completionNotes = '';

  List<String> completionPhotos =
      [];

  String? recoveryReason;

  bool hasProviderLocation = false;

  String? requestError;

  RoadRoute? roadRoute;

  bool routeLoading = false;

  int routeRequestVersion = 0;

  bool confirmingArrival = false;
  bool confirmingCompletion = false;
  bool replacingProvider = false;

  final statuses = const [
    'Accepted',
    'En Route',
    'Arrived',
    'Completed',
  ];

  StreamSubscription<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      requestListener;

  @override
  void initState() {
    super.initState();

    if (widget.requestId == null) {
      requestError =
          'This request is not connected to live tracking.';
      return;
    }

    requestListener =
        RequestService()
            .watchRequest(
      widget.requestId!,
    )
            .listen(
      (snapshot) {
        final data =
            snapshot.data();

        final value =
            data?['status']
                as String?;

        final latitude =
            (data?['providerLatitude']
                    as num?)
                ?.toDouble();

        final longitude =
            (data?['providerLongitude']
                    as num?)
                ?.toDouble();

        final updatedPosition =
            latitude != null &&
                    longitude != null
                ? LatLng(
                    latitude,
                    longitude,
                  )
                : null;

        final shouldRefreshRoute =
            updatedPosition != null &&
                (!hasProviderLocation ||
                    Geolocator.distanceBetween(
                          providerPosition
                              .latitude,
                          providerPosition
                              .longitude,
                          updatedPosition
                              .latitude,
                          updatedPosition
                              .longitude,
                        ) >=
                        20);

        final next =
            switch (value) {
          'accepted' => 0,
          'en_route' => 1,
          'arrived' => 2,
          'completed' => 3,
          _ => status,
        };

        if (!mounted) return;

        setState(() {
          status = next;

          cancelled =
              value == 'cancelled';

          arrivalNeedsConfirmation =
              data?['arrivalVerificationRequired'] ==
                      true &&
                  data?['arrivalConfirmedBy'] ==
                      null;

          arrivalLocationHint =
              updatedPosition == null
                  ? 'Provider GPS is unavailable. Confirm arrival only if you have physically met the provider.'
                  : 'Provider GPS is informational. Confirm arrival only when the provider is physically with you.';

          completionPending =
              data?['completionState'] ==
                  'pending';

          completionNotes =
              data?['serviceNotes']
                      as String? ??
                  '';

          completionPhotos =
              (data?['servicePhotoData']
                          as List? ??
                      [])
                  .whereType<String>()
                  .toList();

          recoveryReason =
              data?['cancellationReason']
                  as String?;

          requestError = null;

          providerName =
              data?['providerName']
                      as String? ??
                  providerName;

          providerPhone =
              data?['providerPhone']
                      as String? ??
                  providerPhone;

          estimatedCost =
              (data?['estimatedCost']
                          as num?)
                      ?.toInt() ??
                  estimatedCost;

          if (updatedPosition !=
              null) {
            providerPosition =
                updatedPosition;

            hasProviderLocation =
                true;
          }
        });

        if (shouldRefreshRoute &&
            updatedPosition != null) {
          unawaited(
            refreshRoadRoute(
              updatedPosition,
            ),
          );
        }
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          requestError =
              'Live updates are temporarily unavailable.';
        });
      },
    );
  }

  @override
  void dispose() {
    requestListener?.cancel();
    super.dispose();
  }

  Future<void> refreshRoadRoute(
    LatLng origin,
  ) async {
    final version =
        ++routeRequestVersion;

    if (mounted) {
      setState(() {
        routeLoading = true;
      });
    }

    try {
      final result =
          await const RouteService()
              .fetchDrivingRoute(
        origin: origin,
        destination: LatLng(
          widget.draft.latitude,
          widget.draft.longitude,
        ),
      );

      if (!mounted ||
          version !=
              routeRequestVersion) {
        return;
      }

      setState(() {
        roadRoute = result;
        routeLoading = false;
      });
    } catch (_) {
      if (!mounted ||
          version !=
              routeRequestVersion) {
        return;
      }

      setState(() {
        routeLoading = false;

        requestError =
            'Road route and ETA are temporarily unavailable.';
      });
    }
  }

  Future<void> confirmArrival() async {
    if (widget.requestId == null ||
        confirmingArrival) {
      return;
    }

    final reason =
        await _adminReason(
      context,
      'Confirm you met the provider. Explain any missing or inaccurate GPS.',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      confirmingArrival = true;
    });

    try {
      await RequestService()
          .confirmProviderArrival(
        widget.requestId!,
        reason,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          confirmingArrival =
              false;
        });
      }
    }
  }

  Future<void>
      replaceDelayedProvider() async {
    if (widget.requestId == null ||
        replacingProvider) {
      return;
    }

    final reason =
        await _adminReason(
      context,
      'Reason for replacing the provider',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      replacingProvider = true;
    });

    try {
      await RequestService()
          .withdrawProvider(
        widget.requestId!,
        reason,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          replacingProvider =
              false;
        });
      }
    }
  }

  Future<void>
      confirmCompletion() async {
    if (widget.requestId == null ||
        confirmingCompletion) {
      return;
    }

    setState(() {
      confirmingCompletion = true;
    });

    try {
      await RequestService()
          .confirmJobCompletion(
        widget.requestId!,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          confirmingCompletion =
              false;
        });
      }
    }
  }

  String get statusTitle {
    if (cancelled) {
      return 'Assistance cancelled';
    }

    return switch (status) {
      0 =>
        'Provider accepted your request',
      1 =>
        'Provider is on the way',
      2 =>
        'Provider has arrived',
      _ =>
        'Assistance completed',
    };
  }

  String get statusDescription {
    if (cancelled) {
      return recoveryReason == null
          ? 'This roadside assistance request is no longer active.'
          : 'The assigned provider is no longer available. You can choose another provider.';
    }

    return switch (status) {
      0 =>
        'Your provider has accepted the job and is preparing to travel to you.',
      1 =>
        'Track the provider on the map while they travel to your breakdown location.',
      2 =>
        'Confirm arrival only after you physically meet the provider.',
      _ =>
        'The roadside assistance workflow has been completed.',
    };
  }

  String get routeTitle {
    if (cancelled) {
      return 'Request cancelled';
    }

    if (status == 3) {
      return 'Assistance completed';
    }

    if (!hasProviderLocation) {
      return 'Waiting for provider location';
    }

    if (routeLoading) {
      return 'Updating driving route';
    }

    if (roadRoute == null) {
      return 'Calculating route';
    }

    return roadRoute!.trafficAware
        ? 'Live traffic route'
        : 'Driving route';
  }

  Widget _buildMap(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .6,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: MapMock(
              position: LatLng(
                widget.draft.latitude,
                widget.draft.longitude,
              ),
              providerPosition:
                  providerPosition,
              routePoints:
                  roadRoute?.points,
              showProviders:
                  hasProviderLocation,
              showRoute:
                  roadRoute != null,
            ),
          ),

          Positioned(
            top: RaSpace.md,
            left: RaSpace.md,
            right: RaSpace.md,
            child: Container(
              padding:
                  const EdgeInsets
                      .all(
                RaSpace.md,
              ),
              decoration:
                  BoxDecoration(
                color: colors.surface
                    .withValues(
                  alpha: .95,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: .08,
                    ),
                    blurRadius: 16,
                    offset:
                        const Offset(
                      0,
                      5,
                    ),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .route_outlined,
                      color: colors
                          .onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(
                    width: RaSpace.sm,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          routeTitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        if (roadRoute !=
                                null &&
                            !cancelled &&
                            status < 3)
                          Text(
                            '${roadRoute!.distanceKm.toStringAsFixed(1)} km • ${roadRoute!.durationMinutes} min',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodySmall,
                          ),
                      ],
                    ),
                  ),

                  if (routeLoading)
                    const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else if (requestError !=
                      null)
                    Icon(
                      Icons
                          .cloud_off_outlined,
                      color:
                          colors.error,
                      size: 19,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          21,
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
        children: [
          Row(
            children: [
              ProfileInitials(
                name: providerName,
                radius: 27,
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
                      providerName,
                      maxLines: 1,
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
                      height: 4,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .verified_outlined,
                          color:
                              raSuccess,
                          size: 16,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Assigned service provider',
                          style: theme
                              .textTheme
                              .bodySmall,
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

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      providerPhone
                              .isEmpty
                          ? null
                          : () =>
                              showCallPrompt(
                                context,
                                name:
                                    providerName,
                                number:
                                    providerPhone,
                              ),
                  icon:
                      const Icon(
                    Icons
                        .call_outlined,
                  ),
                  label:
                      const Text(
                    'Call',
                  ),
                ),
              ),

              const SizedBox(
                width: RaSpace.sm,
              ),

              Expanded(
                child:
                    FilledButton.icon(
                  onPressed:
                      widget.requestId ==
                              null
                          ? null
                          : () =>
                              push(
                                context,
                                ChatScreen(
                                  requestId:
                                      widget
                                          .requestId,
                                  peerName:
                                      providerName,
                                  peerPhone:
                                      providerPhone,
                                ),
                              ),
                  icon:
                      _UnreadChatIcon(
                    requestId:
                        widget
                            .requestId,
                    seenField:
                        'driverMessagesSeenAt',
                  ),
                  label:
                      const Text(
                    'Message',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: cancelled
            ? colors.errorContainer
                .withValues(
                alpha: .28,
              )
            : colors
                .primaryContainer
                .withValues(
                alpha: .26,
              ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: cancelled
                      ? colors
                          .errorContainer
                      : colors
                          .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(
                    15,
                  ),
                ),
                child: Icon(
                  cancelled
                      ? Icons
                          .close_rounded
                      : status == 0
                          ? Icons
                              .handshake_outlined
                          : status == 1
                              ? Icons
                                  .navigation_outlined
                              : status ==
                                      2
                                  ? Icons
                                      .location_on_outlined
                                  : Icons
                                      .task_alt_rounded,
                  color: cancelled
                      ? colors.error
                      : colors
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
                      statusTitle,
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      statusDescription,
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
            ],
          ),

          if (!cancelled) ...[
            const SizedBox(
              height: RaSpace.lg,
            ),

            StatusTimeline(
              statuses: statuses,
              current: status,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestSummary(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
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
        children: [
          _RaTrackDetail(
            icon:
                Icons.car_repair_outlined,
            label: 'Assistance',
            value:
                widget.draft.issue,
          ),

          const _RaTrackDivider(),

          _RaTrackDetail(
            icon:
                Icons.location_on_outlined,
            label: 'Location',
            value:
                widget.draft.location,
          ),

          const _RaTrackDivider(),

          _RaTrackDetail(
            icon:
                Icons.request_quote_outlined,
            label:
                'Approved quote',
            value: estimatedCost > 0
                ? 'Rs. $estimatedCost'
                : 'Price pending',
          ),

          if (widget.requestId !=
              null) ...[
            const _RaTrackDivider(),

            _RaTrackDetail(
              icon:
                  Icons.tag_rounded,
              label: 'Request ID',
              value:
                  widget.requestId!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArrivalConfirmation(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors
            .tertiaryContainer
            .withValues(
          alpha: .38,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .person_pin_circle_outlined,
                color: colors
                    .onTertiaryContainer,
              ),
              const SizedBox(
                width: RaSpace.sm,
              ),
              Expanded(
                child: Text(
                  'Confirm provider arrival',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.sm,
          ),

          Text(
            arrivalLocationHint,
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          FilledButton.icon(
            onPressed:
                confirmingArrival
                    ? null
                    : confirmArrival,
            icon: confirmingArrival
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .check_circle_outline_rounded,
                  ),
            label: const Text(
              'Provider Is Here',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionReview(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: raSuccess
              .withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: raSuccessPale,
                  borderRadius:
                      BorderRadius
                          .circular(14),
                ),
                child: const Icon(
                  Icons
                      .task_alt_rounded,
                  color:
                      raSuccess,
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
                      'Review completed work',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      'Confirm only after checking that the agreed work has been completed.',
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (completionNotes
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: RaSpace.md,
            ),
            Text(
              'Provider notes',
              style: theme
                  .textTheme.labelLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              completionNotes,
            ),
          ],

          if (completionPhotos
              .isNotEmpty) ...[
            const SizedBox(
              height: RaSpace.md,
            ),
            RevisionEvidencePhotos(
              photos:
                  completionPhotos,
            ),
          ],

          const SizedBox(
            height: RaSpace.lg,
          ),

          FilledButton.icon(
            onPressed:
                confirmingCompletion
                    ? null
                    : confirmCompletion,
            icon: confirmingCompletion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .verified_outlined,
                  ),
            label: const Text(
              'Confirm Work Completed',
            ),
          ),

          const SizedBox(
            height: RaSpace.sm,
          ),

          TextButton.icon(
            style:
                TextButton.styleFrom(
              foregroundColor:
                  colors.error,
            ),
            onPressed: () => push(
              context,
              DisputeScreen(
                requestId:
                    widget.requestId!,
              ),
            ),
            icon: const Icon(
              Icons
                  .report_problem_outlined,
            ),
            label: const Text(
              'There Is a Problem',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer
            .withValues(
          alpha: .34,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .person_off_outlined,
            color: colors.error,
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
                  'Provider unavailable',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  recoveryReason ??
                      'The assigned provider is no longer available.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    height: 1.4,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  'Choose another provider and approve a new offer before continuing.',
                  style: theme
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
        ],
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
        title: const Text(
          'Track Assistance',
        ),
        actions: [
          if (widget.requestId !=
              null)
            IconButton(
              tooltip:
                  'Invoice',
              onPressed: () =>
                  push(
                context,
                InvoiceScreen(
                  requestId:
                      widget
                          .requestId!,
                ),
              ),
              icon: const Icon(
                Icons
                    .receipt_long_outlined,
              ),
            ),

          IconButton(
            tooltip:
                'Emergency',
            onPressed: () =>
                push(
              context,
              const EmergencyScreen(),
            ),
            style:
                IconButton.styleFrom(
              backgroundColor:
                  colors.errorContainer
                      .withValues(
                alpha: .65,
              ),
              foregroundColor:
                  colors.error,
            ),
            icon: const Icon(
              Icons.sos_outlined,
            ),
          ),

          const SizedBox(
            width: RaSpace.sm,
          ),
        ],
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
                  RaSpace.md,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  if (widget.requestId !=
                      null) ...[
                    RepairQuotePanel(
                      requestId:
                          widget
                              .requestId!,
                    ),
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),
                  ],

                  _buildMap(
                    context,
                  ),

                  if (requestError !=
                      null) ...[
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .all(
                        RaSpace.md,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .errorContainer
                            .withValues(
                          alpha: .35,
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
                            Icons
                                .cloud_off_outlined,
                            color: colors
                                .error,
                            size: 19,
                          ),
                          const SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          Expanded(
                            child: Text(
                              requestError!,
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildProviderCard(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xl,
                  ),

                  _buildStatusCard(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildRequestSummary(
                    context,
                  ),

                  if (!cancelled &&
                      status == 0 &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    TextButton.icon(
                      onPressed:
                          replacingProvider
                              ? null
                              : replaceDelayedProvider,
                      icon: replacingProvider
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .person_search_outlined,
                            ),
                      label: const Text(
                        'Provider Has Not Departed? Replace Provider',
                      ),
                    ),

                    Text(
                      'Replacement is intended for cases where the provider does not depart after the allowed waiting period.',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (!cancelled &&
                      status == 2 &&
                      arrivalNeedsConfirmation) ...[
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    _buildArrivalConfirmation(
                      context,
                    ),
                  ],

                  if (completionPending &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    _buildCompletionReview(
                      context,
                    ),
                  ],

                  if (cancelled &&
                      recoveryReason !=
                          null) ...[
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    _buildRecoveryCard(
                      context,
                    ),
                  ],
                ],
              ),
            ),

            _RaTrackingBottomBar(
              cancelled:
                  cancelled,
              completed:
                  status == 3,
              canFindAnother:
                  cancelled &&
                      recoveryReason !=
                          null,
              onPressed: () {
                if (cancelled &&
                    recoveryReason !=
                        null) {
                  replace(
                    context,
                    ReviewScreen(
                      draft:
                          widget.draft
                              .copyWith(
                        provider: '',
                        preferredProviderId:
                            '',
                      ),
                    ),
                  );
                } else {
                  replace(
                    context,
                    const DriverShell(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RaTrackDetail
    extends StatelessWidget {
  const _RaTrackDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: RaSpace.sm,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: colors.primary,
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
                  label,
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
                  value,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaTrackDivider
    extends StatelessWidget {
  const _RaTrackDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 50,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(
            alpha: .5,
          ),
    );
  }
}

class _RaTrackingBottomBar
    extends StatelessWidget {
  const _RaTrackingBottomBar({
    required this.cancelled,
    required this.completed,
    required this.canFindAnother,
    required this.onPressed,
  });

  final bool cancelled;
  final bool completed;
  final bool canFindAnother;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final enabled =
        cancelled || completed;

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
                .withValues(
              alpha: .6,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child:
              FilledButton.icon(
            onPressed:
                enabled
                    ? onPressed
                    : null,
            icon: Icon(
              canFindAnother
                  ? Icons
                      .person_search_outlined
                  : completed ||
                          cancelled
                      ? Icons
                          .home_outlined
                      : Icons
                          .hourglass_top_rounded,
            ),
            label: Text(
              canFindAnother
                  ? 'Find Another Provider'
                  : completed ||
                          cancelled
                      ? 'Back to Home'
                      : 'Waiting for Provider Update',
            ),
          ),
        ),
      ),
    );
  }
}