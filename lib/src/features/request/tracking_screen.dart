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

  LatLng? providerPosition;

  String providerName = 'Service Provider';
  String providerPhone = '';

  int estimatedCost = 0;

  bool cancelled = false;

  bool arrivalNeedsConfirmation = false;
  String arrivalLocationHint = '';

  bool completionPending = false;
  String completionNotes = '';
  List<String> completionPhotos = [];

  String? recoveryReason;
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
      DocumentSnapshot<Map<String, dynamic>>>? requestListener;

  @override
  void initState() {
    super.initState();

    final requestId = widget.requestId;

    if (requestId == null) {
      requestError =
          'This request is not connected to live tracking.';
      return;
    }

    requestListener = RequestService()
        .watchRequest(requestId)
        .listen(
      _handleRequestUpdate,
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

  void _handleRequestUpdate(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (!mounted || data == null) {
      return;
    }

    final value =
        data['status'] as String? ?? 'accepted';

    final latitude =
        (data['providerLatitude'] as num?)?.toDouble();

    final longitude =
        (data['providerLongitude'] as num?)?.toDouble();

    final updatedPosition =
        latitude != null && longitude != null
            ? LatLng(
                latitude,
                longitude,
              )
            : null;

    var shouldRefreshRoute = false;

    if (updatedPosition != null) {
      final old = providerPosition;

      if (old == null) {
        shouldRefreshRoute = true;
      } else {
        final movement =
            Geolocator.distanceBetween(
          old.latitude,
          old.longitude,
          updatedPosition.latitude,
          updatedPosition.longitude,
        );

        shouldRefreshRoute =
            movement >= 20;
      }
    }

    final nextStatus = switch (value) {
      'accepted' => 0,
      'en_route' => 1,
      'arrived' => 2,
      'completed' => 3,
      _ => status,
    };

    setState(() {
      status = nextStatus;

      cancelled =
          value == 'cancelled';

      arrivalNeedsConfirmation =
          data['arrivalVerificationRequired'] == true &&
              data['arrivalConfirmedBy'] == null;

      arrivalLocationHint =
          updatedPosition == null
              ? 'Provider GPS is unavailable. Confirm arrival only if you have physically met the provider.'
              : 'Provider GPS is informational. Confirm arrival only when the provider is physically with you.';

      completionPending =
          data['completionState'] == 'pending';

      completionNotes =
          data['serviceNotes'] as String? ?? '';

      completionPhotos =
          (data['servicePhotoData'] as List? ?? const [])
              .whereType<String>()
              .toList();

      recoveryReason =
          data['cancellationReason'] as String?;

      providerName =
          data['providerName'] as String? ??
              providerName;

      providerPhone =
          data['providerPhone'] as String? ??
              providerPhone;

      estimatedCost =
          (data['estimatedCost'] as num?)?.toInt() ??
              estimatedCost;

      if (updatedPosition != null) {
        providerPosition =
            updatedPosition;
      }

      requestError = null;
    });

    if (shouldRefreshRoute &&
        updatedPosition != null) {
      unawaited(
        refreshRoadRoute(
          updatedPosition,
        ),
      );
    }
  }

  Future<void> refreshRoadRoute(
    LatLng origin,
  ) async {
    final version =
        ++routeRequestVersion;

    setState(() {
      routeLoading = true;
    });

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
          version != routeRequestVersion) {
        return;
      }

      setState(() {
        roadRoute = result;
        routeLoading = false;
      });
    } catch (_) {
      if (!mounted ||
          version != routeRequestVersion) {
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
    final requestId =
        widget.requestId;

    if (requestId == null ||
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
        requestId,
        reason,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          confirmingArrival = false;
        });
      }
    }
  }

  Future<void>
      replaceDelayedProvider() async {
    final requestId =
        widget.requestId;

    if (requestId == null ||
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
        requestId,
        reason,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          replacingProvider = false;
        });
      }
    }
  }

  Future<void>
      confirmCompletion() async {
    final requestId =
        widget.requestId;

    if (requestId == null ||
        confirmingCompletion) {
      return;
    }

    setState(() {
      confirmingCompletion = true;
    });

    try {
      await RequestService()
          .confirmJobCompletion(
        requestId,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          confirmingCompletion = false;
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
        'Your provider accepted the job and is preparing to travel to you.',
      1 =>
        'Follow the live provider location while they travel to your breakdown point.',
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

    if (providerPosition == null) {
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

  String money(
    int value,
  ) {
    final digits =
        value.abs().toString();

    final buffer =
        StringBuffer();

    for (var index = 0;
        index < digits.length;
        index++) {
      if (index > 0 &&
          (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(
        digits[index],
      );
    }

    return 'Rs. ${value < 0 ? '-' : ''}${buffer.toString()}';
  }

  Widget buildMap(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final provider =
        providerPosition;

    return Container(
      height: 285,
      clipBehavior:
          Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          23,
        ),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: .48,
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
                  provider,
              routePoints:
                  roadRoute?.points,
              showProviders:
                  provider != null,
              showRoute:
                  provider != null &&
                      roadRoute != null,
            ),
          ),

          Positioned(
            top: 11,
            left: 11,
            right: 11,
            child: Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color: colors.surface
                    .withValues(
                  alpha: .96,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                border: Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .30,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primary
                          .withValues(
                        alpha: .08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .route_outlined,
                      color:
                          colors.primary,
                      size: 19,
                    ),
                  ),

                  const SizedBox(
                    width: 9,
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
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        if (roadRoute != null &&
                            !cancelled &&
                            status < 3) ...[
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            '${roadRoute!.distanceKm.toStringAsFixed(1)} km • ${roadRoute!.durationMinutes} min',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 8.5,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (routeLoading)
                    const SizedBox.square(
                      dimension: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (provider == null &&
              !cancelled &&
              status < 3)
            Positioned(
              left: 11,
              right: 11,
              bottom: 11,
              child: Container(
                padding:
                    const EdgeInsets.all(
                  11,
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
                    15,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .location_searching_rounded,
                      color:
                          colors.primary,
                      size: 18,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        'The provider has not shared a live GPS location yet.',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 9,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildProviderCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileInitials(
                name:
                    providerName,
                radius: 25,
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight
                                .w800,
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
                          size: 14,
                          color:
                              raSuccess,
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Text(
                          'Assigned RoadAssist provider',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 8.5,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      providerPhone
                              .trim()
                              .isEmpty
                          ? null
                          : () {
                              showCallPrompt(
                                context,
                                name:
                                    providerName,
                                number:
                                    providerPhone,
                              );
                            },
                  icon: const Icon(
                    Icons.call_outlined,
                  ),
                  label:
                      const Text(
                    'Call',
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child:
                    FilledButton.icon(
                  onPressed:
                      widget.requestId ==
                              null
                          ? null
                          : () {
                              push(
                                context,
                                ChatScreen(
                                  requestId:
                                      widget.requestId,
                                  peerName:
                                      providerName,
                                  peerPhone:
                                      providerPhone,
                                ),
                              );
                            },
                  icon: _UnreadChatIcon(
                    requestId:
                        widget.requestId,
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

  Widget buildStatusCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final tone =
        cancelled
            ? colors.error
            : status == 3
                ? raSuccess
                : colors.primary;

    final icon =
        cancelled
            ? Icons.close_rounded
            : switch (status) {
                0 =>
                  Icons.handshake_outlined,
                1 =>
                  Icons.navigation_outlined,
                2 =>
                  Icons.location_on_outlined,
                _ =>
                  Icons.task_alt_rounded,
              };

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: .07,
        ),
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        border: Border.all(
          color: tone.withValues(
            alpha: .17,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(
                    alpha: .11,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      statusTitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 14,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      statusDescription,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9.3,
                        height: 1.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!cancelled) ...[
            const SizedBox(
              height: 17,
            ),

            StatusTimeline(
              statuses:
                  statuses,
              current: status,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildRequestSummary(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final vehicle =
        [
          widget.draft.modelYear,
          widget.draft.registration,
        ]
            .where(
              (value) =>
                  value.trim().isNotEmpty,
            )
            .join(' • ');

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        children: [
          _RaTrackDetail(
            icon: Icons
                .car_repair_outlined,
            label: 'Assistance',
            value:
                widget.draft.issue,
          ),

          const _RaTrackDivider(),

          if (vehicle.isNotEmpty) ...[
            _RaTrackDetail(
              icon: Icons
                  .directions_car_outlined,
              label: 'Vehicle',
              value: vehicle,
            ),

            const _RaTrackDivider(),
          ],

          _RaTrackDetail(
            icon: Icons
                .location_on_outlined,
            label: 'Location',
            value:
                widget.draft.location,
          ),

          if (widget.draft.landmark
              .trim()
              .isNotEmpty) ...[
            const _RaTrackDivider(),

            _RaTrackDetail(
              icon:
                  Icons.signpost_outlined,
              label: 'Landmark',
              value:
                  widget.draft.landmark,
            ),
          ],

          const _RaTrackDivider(),

          _RaTrackDetail(
            icon: Icons
                .request_quote_outlined,
            label:
                'Approved quote',
            value:
                estimatedCost > 0
                    ? money(
                        estimatedCost,
                      )
                    : 'Price pending',
          ),

          if (widget.requestId !=
              null) ...[
            const _RaTrackDivider(),

            _RaTrackDetail(
              icon:
                  Icons.tag_rounded,
              label:
                  'Request ID',
              value:
                  widget.requestId!,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildArrivalConfirmation(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: raGold.withValues(
          alpha: .075,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border: Border.all(
          color: raGold.withValues(
            alpha: .18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: raGold
                      .withValues(
                    alpha: .12,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .person_pin_circle_outlined,
                  color: raGold,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  'Confirm provider arrival',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            arrivalLocationHint,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 9.3,
              height: 1.45,
              color: colors
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          FilledButton.icon(
            onPressed:
                confirmingArrival
                    ? null
                    : confirmArrival,
            icon: confirmingArrival
                ? const SizedBox.square(
                    dimension: 17,
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

  Widget buildCompletionReview(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: raSuccess.withValues(
            alpha: .30,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: raSuccess
                      .withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color:
                      raSuccess,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Review completed work',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Confirm only after checking the agreed service.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.8,
                        color: colors
                            .onSurfaceVariant,
                      ),
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
              height: 14,
            ),

            Text(
              'Provider notes',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              completionNotes,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 9.5,
                height: 1.45,
              ),
            ),
          ],

          if (completionPhotos
              .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            RevisionEvidencePhotos(
              photos:
                  completionPhotos,
            ),
          ],

          const SizedBox(
            height: 16,
          ),

          FilledButton.icon(
            onPressed:
                confirmingCompletion
                    ? null
                    : confirmCompletion,
            icon:
                confirmingCompletion
                    ? const SizedBox.square(
                        dimension: 17,
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
            height: 7,
          ),

          TextButton.icon(
            style:
                TextButton.styleFrom(
              foregroundColor:
                  colors.error,
            ),
            onPressed:
                widget.requestId == null
                    ? null
                    : () {
                        push(
                          context,
                          DisputeScreen(
                            requestId:
                                widget.requestId!,
                          ),
                        );
                      },
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

  Widget buildRecoveryCard(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: colors.error
            .withValues(
          alpha: .07,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border: Border.all(
          color: colors.error
              .withValues(
            alpha: .18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color: colors.error
                  .withValues(
                alpha: .11,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                14,
              ),
            ),
            child: Icon(
              Icons
                  .person_off_outlined,
              color:
                  colors.error,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Provider unavailable',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  recoveryReason ??
                      'The assigned provider is no longer available.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.2,
                    height: 1.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Choose another provider and approve a new offer before continuing.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.8,
                    color: colors
                        .onSurfaceVariant,
                  ),
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

    return RaScaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Track Assistance',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        actions: [
          if (widget.requestId != null &&
              status == 3)
            IconButton(
              tooltip:
                  'Invoice',
              onPressed: () {
                push(
                  context,
                  InvoiceScreen(
                    requestId:
                        widget.requestId!,
                  ),
                );
              },
              icon: const Icon(
                Icons
                    .receipt_long_outlined,
              ),
            ),

          IconButton(
            tooltip: 'Emergency',
            style:
                IconButton.styleFrom(
              foregroundColor:
                  colors.error,
            ),
            onPressed: () {
              push(
                context,
                const EmergencyScreen(),
              );
            },
            icon: const Icon(
              Icons.sos_outlined,
            ),
          ),

          const SizedBox(
            width: 4,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics:
                    const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  28,
                ),
                children: [
                  if (widget.requestId !=
                      null) ...[
                    RepairQuotePanel(
                      requestId:
                          widget.requestId!,
                    ),

                    const SizedBox(
                      height: 13,
                    ),
                  ],

                  buildMap(
                    context,
                  ),

                  if (requestError !=
                      null) ...[
                    const SizedBox(
                      height: 11,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors.error
                            .withValues(
                          alpha: .07,
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
                            color:
                                colors.error,
                            size: 18,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Text(
                              requestError!,
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize:
                                    9,
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 14,
                  ),

                  buildProviderCard(
                    context,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  buildStatusCard(
                    context,
                  ),

                  const SizedBox(
                    height: 13,
                  ),

                  buildRequestSummary(
                    context,
                  ),

                  if (!cancelled &&
                      status == 0 &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height: 13,
                    ),

                    OutlinedButton.icon(
                      onPressed:
                          replacingProvider
                              ? null
                              : replaceDelayedProvider,
                      icon:
                          replacingProvider
                              ? const SizedBox.square(
                                  dimension:
                                      16,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
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

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Use replacement only when the assigned provider has not departed after the expected waiting period.',
                      textAlign:
                          TextAlign.center,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (!cancelled &&
                      status == 2 &&
                      arrivalNeedsConfirmation) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    buildArrivalConfirmation(
                      context,
                    ),
                  ],

                  if (completionPending &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    buildCompletionReview(
                      context,
                    ),
                  ],

                  if (cancelled &&
                      recoveryReason !=
                          null) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    buildRecoveryCard(
                      context,
                    ),
                  ],

                  if (status == 3 &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height: 17,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed: () {
                          push(
                            context,
                            InvoiceScreen(
                              requestId:
                                  widget.requestId!,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons
                              .receipt_long_outlined,
                        ),
                        label: const Text(
                          'View Service Invoice',
                        ),
                      ),
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
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .07,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  colors.primary,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  label,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.3,
                    height: 1.4,
                    fontWeight:
                        FontWeight
                            .w600,
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
      indent: 48,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(
            alpha: .34,
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
        Theme.of(context)
            .colorScheme;

    final enabled =
        cancelled || completed;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors
                .outlineVariant
                .withValues(
              alpha: .45,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width:
              double.infinity,
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
                  : enabled
                      ? Icons
                          .home_outlined
                      : Icons
                          .hourglass_top_rounded,
            ),
            label: Text(
              canFindAnother
                  ? 'Find Another Provider'
                  : enabled
                      ? 'Back to Home'
                      : 'Waiting for Provider Update',
            ),
          ),
        ),
      ),
    );
  }
}