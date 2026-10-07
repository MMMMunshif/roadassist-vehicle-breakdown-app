part of '../../screens.dart';

class ProviderHomeScreen
    extends StatefulWidget {
  const ProviderHomeScreen({
    super.key,
  });

  @override
  State<ProviderHomeScreen>
      createState() =>
          _ProviderHomeScreenState();
}

class _ProviderHomeScreenState
    extends State<ProviderHomeScreen>
    with WidgetsBindingObserver {
  bool online = false;

  Map<String, dynamic> availability =
      {};

  Timer? availabilityClock;

  bool savingPresence = false;

  StreamSubscription<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      directorySubscription;

  String serviceRadius =
      '15 km from current location';

  List<String> providerServices =
      const [
    'Vehicle Towing',
    'Battery Jumpstart',
    'Flat Tyre',
    'General Mechanic',
  ];

  StreamSubscription<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      profileSubscription;

  StreamSubscription<
          QuerySnapshot<
              Map<String, dynamic>>>?
      openRequestsSubscription;

  Set<String> knownOpenRequestIds =
      <String>{};

  bool openRequestsInitialized =
      false;

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

    WidgetsBinding.instance
        .addObserver(this);

    final uid =
        FirebaseAuth
            .instance.currentUser?.uid;

    if (uid != null) {
      directorySubscription =
          FirebaseFirestore.instance
              .collection(
                'providerDirectory',
              )
              .doc(uid)
              .snapshots()
              .listen(
        (snapshot) {
          if (!mounted ||
              savingPresence) {
            return;
          }

          setState(() {
            online =
                snapshot.data()?[
                        'online'] ==
                    true;

            availability =
                snapshot.data() ??
                    {};
          });
        },
        onError:
            (Object error) {},
      );
    }

    unawaited(
      _publishProviderLocation(),
    );

    profileSubscription =
        AuthService()
            .watchCurrentProfile()
            .listen(
      (snapshot) {
        final savedServices =
            snapshot.data()?[
                    'services']
                as List<dynamic>?;

        final savedRadius =
            snapshot.data()?[
                    'serviceRadius']
                as String?;

        if (!mounted) return;

        setState(() {
          if (savedServices !=
                  null &&
              savedServices
                  .isNotEmpty) {
            providerServices =
                savedServices
                    .whereType<
                        String>()
                    .toList();
          }

          if (savedRadius != null &&
              savedRadius
                  .trim()
                  .isNotEmpty) {
            serviceRadius =
                savedRadius;
          }
        });
      },
      onError:
          (Object error) {},
    );

    openRequestsSubscription =
        RequestService()
            .watchOpenRequests()
            .listen(
      _handleOpenRequestUpdates,
      onError:
          (Object error) {},
    );
  }

  String get dashboardTitle {
    final towing =
        providerServices.contains(
      'Vehicle Towing',
    );

    final mechanic =
        providerServices.contains(
              'General Mechanic',
            ) ||
            providerServices.contains(
              'Flat Tyre',
            ) ||
            providerServices.contains(
              'Battery Jumpstart',
            );

    if (towing && !mechanic) {
      return 'Tow Operator Dashboard';
    }

    if (mechanic && !towing) {
      return 'Mechanic Dashboard';
    }

    return 'Provider Dashboard';
  }

  String get providerSpecialty {
    if (providerServices.isEmpty) {
      return 'Roadside assistance professional';
    }

    if (providerServices.length ==
        1) {
      return providerServices.first;
    }

    return '${providerServices.first} + ${providerServices.length - 1} more';
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
            AppLifecycleState.resumed &&
        signedIn &&
        online) {
      unawaited(
        _publishProviderLocation(),
      );
    }
  }

  Future<void>
      _publishProviderLocation() async {
    try {
      await AuthService()
          .syncProviderDirectory();

      if (!await Geolocator
          .isLocationServiceEnabled()) {
        return;
      }

      var permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission
                  .denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      await AuthService()
          .updateProviderDirectoryLocation(
        latitude:
            position.latitude,
        longitude:
            position.longitude,
      );
    } catch (_) {
      // Matching can continue using the
      // provider's previous known location.
    }
  }

  void _handleOpenRequestUpdates(
    QuerySnapshot<
            Map<String, dynamic>>
        snapshot,
  ) {
    final userId =
        FirebaseAuth
            .instance.currentUser?.uid;

    if (userId == null) return;

    final matchingRequests =
        snapshot.docs.where(
      (request) {
        return _requestMatchesProvider(
          request.data(),
          userId,
          services:
              providerServices,
        );
      },
    ).toList();

    final currentIds =
        matchingRequests
            .map(
              (request) =>
                  request.id,
            )
            .toSet();

    if (!openRequestsInitialized) {
      knownOpenRequestIds =
          currentIds;

      openRequestsInitialized =
          true;

      return;
    }

    final newRequests =
        matchingRequests
            .where(
              (request) =>
                  !knownOpenRequestIds
                      .contains(
                request.id,
              ),
            )
            .toList();

    knownOpenRequestIds =
        currentIds;

    if (!mounted ||
        _providerAvailabilityStatus(
              availability,
            ) !=
            'Online' ||
        newRequests.isEmpty) {
      return;
    }

    final latest =
        newRequests.first.data();

    final driverName =
        latest['driverName']
                as String? ??
            'A driver';

    final issue =
        latest['issue']
                as String? ??
            'roadside assistance';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(
            seconds: 8,
          ),
          content: Text(
            '$driverName needs $issue',
          ),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => push(
              context,
              const ProviderNotificationsScreen(),
            ),
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    profileSubscription?.cancel();
    directorySubscription?.cancel();
    openRequestsSubscription
        ?.cancel();
    availabilityClock?.cancel();

    super.dispose();
  }

  Future<void> _changeOnline(
    bool value,
  ) async {
    final previous = online;

    setState(() {
      online = value;
      savingPresence = true;
    });

    try {
      await AuthService()
          .setProviderOnline(
        value,
      );

      if (value) {
        unawaited(
          _publishProviderLocation(),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        online = previous;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not change availability. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingPresence = false;
        });
      }
    }
  }

  Future<void> _togglePaused(
    bool paused,
  ) async {
    try {
      await AuthService()
          .setProviderAvailability(
        paused: paused,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update availability.',
          ),
        ),
      );
    }
  }

  Future<void>
      _enableOutsideHours() async {
    try {
      await AuthService()
          .setProviderAvailability(
        overrideHours: true,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not enable outside-hours availability.',
          ),
        ),
      );
    }
  }

  Future<void> _reviewAndQuote(
    Map<String, dynamic> data,
    String requestId,
  ) async {
    try {
      final quote =
          await requestProviderQuote(
        context,
        data,
      );

      if (quote == null ||
          !mounted) {
        return;
      }

      await RequestService()
          .acceptRequest(
        requestId,
        serviceFee:
            quote['serviceFee']
                as int,
        travelFee:
            quote['travelFee']
                as int,
        extraFee:
            quote['extraFee']
                as int,
        providerDistanceKm:
            quote[
                    'providerDistanceKm']
                as double,
        quoteNotes:
            quote['quoteNotes']
                as String,
        quoteType:
            quote['quoteType']
                as String,
        warrantyDays:
            quote['warrantyDays']
                as int,
        warrantyTerms:
            quote['warrantyTerms']
                as String,
      );

      if (data['workflowVersion'] ==
          2) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Offer sent. The driver will choose a provider.',
            ),
          ),
        );

        return;
      }

      final acceptedData =
          Map<String, dynamic>.from(
        data,
      )
            ..addAll(quote)
            ..['dispatchFee'] =
                quote['travelFee']
            ..['estimatedCost'] =
                (quote['serviceFee']
                        as int) +
                    (quote['travelFee']
                        as int) +
                    (quote['extraFee']
                        as int)
            ..['status'] =
                'accepted';

      if (!mounted) return;

      push(
        context,
        ProviderActiveJobScreen(
          requestId: requestId,
          requestData:
              acceptedData,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final activeJobExists =
          error
              .toString()
              .contains(
                'Complete your active job',
              );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            activeJobExists
                ? 'Complete your active job before accepting another request.'
                : 'This request was cancelled or accepted by another provider.',
          ),
        ),
      );
    }
  }

  Widget requestCard({
    required Map<String, dynamic>
        data,
    required String requestId,
  }) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final latitude =
        (data['latitude'] as num?)
            ?.toDouble();

    final longitude =
        (data['longitude'] as num?)
            ?.toDouble();

    final priority =
        data['priority']
                as String? ??
            'normal';

    final highlighted =
        isHighPriority(priority);

    final driverName =
        data['driverName']
                as String? ??
            'Driver';

    final model =
        data['modelYear']
                as String? ??
            'Vehicle details unavailable';

    final location =
        data['locationLabel']
                as String? ??
            'Pinned location';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: highlighted
              ? colors.error
                  .withValues(
                  alpha: .55,
                )
              : colors
                  .outlineVariant
                  .withValues(
                  alpha: .6,
                ),
          width: highlighted
              ? 1.5
              : 1,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (highlighted)
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    RaSpace.md,
                vertical:
                    RaSpace.sm,
              ),
              color: colors
                  .errorContainer
                  .withValues(
                alpha: .55,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .warning_amber_rounded,
                    color:
                        colors.error,
                    size: 19,
                  ),
                  const SizedBox(
                    width: RaSpace.sm,
                  ),
                  Expanded(
                    child: Text(
                      requestPriorityLabel(
                        priority,
                      ).toUpperCase(),
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color:
                            colors.error,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (latitude != null &&
              longitude != null)
            SizedBox(
              height: 155,
              child: MapMock(
                position: LatLng(
                  latitude,
                  longitude,
                ),
              ),
            ),

          Padding(
            padding:
                const EdgeInsets.all(
              RaSpace.lg,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Row(
                  children: [
                    ProfileInitials(
                      name: driverName,
                      radius: 23,
                    ),
                    const SizedBox(
                      width:
                          RaSpace.md,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            driverName,
                            maxLines: 1,
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
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            requestIssueLabel(
                              data,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const StatusPill(
                      label: 'NEW',
                      tone:
                          RaTone.warning,
                      dot: false,
                    ),
                  ],
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                _ProviderHomeInfoRow(
                  icon: Icons
                      .directions_car_outlined,
                  label: 'Vehicle',
                  value: model,
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                _ProviderHomeInfoRow(
                  icon: Icons
                      .location_on_outlined,
                  label: 'Location',
                  value: location,
                ),

                if (data[
                        'vehicleSnapshot']
                    is Map) ...[
                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),
                  _ProviderHomeInfoRow(
                    icon: Icons
                        .settings_outlined,
                    label:
                        'Fuel / transmission',
                    value:
                        '${(data['vehicleSnapshot'] as Map)['fuelType'] ?? 'Not provided'} / ${(data['vehicleSnapshot'] as Map)['transmission'] ?? 'Not provided'}',
                  ),
                ],

                const SizedBox(
                  height: RaSpace.md,
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
                        .primaryContainer
                        .withValues(
                      alpha: .30,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .request_quote_outlined,
                        color:
                            colors.primary,
                        size: 19,
                      ),
                      const SizedBox(
                        width:
                            RaSpace.sm,
                      ),
                      Expanded(
                        child: Text(
                          data['workflowVersion'] ==
                                  2
                              ? 'Send an itemized offer for driver approval'
                              : 'Estimated: Rs. ${data['estimatedCost'] ?? 0}',
                          style: theme
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color: colors
                                .primary,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton(
                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              colors
                                  .error,
                        ),
                        onPressed:
                            () async {
                          await RequestService()
                              .rejectRequest(
                            requestId,
                          );
                        },
                        child: const Text(
                          'Dismiss',
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),

                    Expanded(
                      flex: 2,
                      child:
                          FilledButton.icon(
                        onPressed:
                            () =>
                                _reviewAndQuote(
                          data,
                          requestId,
                        ),
                        icon: const Icon(
                          Icons
                              .request_quote_outlined,
                        ),
                        label: const Text(
                          'Review & Quote',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityHero(
    BuildContext context,
    String name,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final availabilityLabel =
        _providerAvailabilityStatus(
      availability,
    );

    final active =
        availabilityLabel ==
            'Online';

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
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
          Row(
            children: [
              _ProviderPresenceAvatar(
                name: name,
                online: online,
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
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      online
                          ? providerSpecialty
                          : 'You are currently offline',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .80,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: online,
                onChanged:
                    savingPresence
                        ? null
                        : _changeOnline,
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.lg,
          ),

          Wrap(
            spacing: RaSpace.sm,
            runSpacing: RaSpace.sm,
            children: [
              _ProviderHeroChip(
                icon: active
                    ? Icons
                        .circle
                    : Icons
                        .pause_circle_outline_rounded,
                text:
                    availabilityLabel,
              ),
              _ProviderHeroChip(
                icon:
                    Icons.radar_outlined,
                text:
                    serviceRadius,
              ),
            ],
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
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        title: Text(
          dashboardTitle,
        ),
        actions: [
          const _ChatInbox(
            isProvider: true,
            buttonOnly: true,
          ),
          _ProviderRequestBadge(
            services:
                providerServices,
          ),
          IconButton(
            tooltip:
                'Refresh location',
            onPressed:
                online
                    ? () =>
                        unawaited(
                          _publishProviderLocation(),
                        )
                    : null,
            icon: const Icon(
              Icons
                  .my_location_outlined,
            ),
          ),
          const SizedBox(
            width: RaSpace.xs,
          ),
        ],
      ),

      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          StreamBuilder<
              DocumentSnapshot<
                  Map<String,
                      dynamic>>>(
            stream: AuthService()
                .watchCurrentProfile(),
            builder: (
              context,
              snapshot,
            ) {
              final name =
                  snapshot.data
                          ?.data()?[
                      'displayName']
                      as String? ??
                  FirebaseAuth
                      .instance
                      .currentUser
                      ?.displayName ??
                  'Service Provider';

              return _availabilityHero(
                context,
                name,
              );
            },
          ),

          const SizedBox(
            height: RaSpace.lg,
          ),

          _ProviderRealtimeStats(
            services:
                providerServices,
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          _ProviderNewRequestsBanner(
            services:
                providerServices,
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          const _ProviderActiveJobsSection(),

          const SizedBox(
            height: RaSpace.xl,
          ),

          const _ProviderEarningsPanel(),

          const SizedBox(
            height: RaSpace.xl,
          ),

          _ProviderServicesOverview(
            services:
                providerServices,
            serviceRadius:
                serviceRadius,
            onManage: () => push(
              context,
              const ProviderProfileScreen(),
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
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
                      'Incoming requests',
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
                      'Newest matching roadside request available to you.',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              TextButton(
                onPressed: () => push(
                  context,
                  const ProviderNotificationsScreen(),
                ),
                child: const Text(
                  'View all',
                ),
              ),
            ],
          ),

          if (online) ...[
            const SizedBox(
              height: RaSpace.md,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .all(
                RaSpace.md,
              ),
              decoration:
                  BoxDecoration(
                color: colors.surface,
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
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
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    secondary: Icon(
                      availability[
                                  'requestsPaused'] ==
                              true
                          ? Icons
                              .pause_circle_outline_rounded
                          : Icons
                              .notifications_active_outlined,
                      color:
                          colors.primary,
                    ),
                    title: const Text(
                      'Pause new requests',
                    ),
                    subtitle:
                        const Text(
                      'Your active job continues while new requests are paused.',
                    ),
                    value: availability[
                            'requestsPaused'] ==
                        true,
                    onChanged:
                        _togglePaused,
                  ),

                  if (!ProviderAvailability
                      .withinHours(
                    availability,
                    DateTime.now(),
                  ))
                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _enableOutsideHours,
                        icon: const Icon(
                          Icons
                              .schedule_outlined,
                        ),
                        label: const Text(
                          'Accept Outside Hours for 2 Hours',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(
            height: RaSpace.md,
          ),

          if (!online)
            Container(
              padding:
                  const EdgeInsets.all(
                RaSpace.xl,
              ),
              decoration:
                  BoxDecoration(
                color: colors.surface,
                borderRadius:
                    BorderRadius
                        .circular(
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
              child: const EmptyState(
                icon: Icons
                    .cloud_off_outlined,
                title:
                    'You are offline',
                message:
                    'Go online to receive nearby assistance requests.',
              ),
            )
          else if (FirebaseAuth
                  .instance
                  .currentUser ==
              null)
            const EmptyState(
              icon:
                  Icons.login_outlined,
              title:
                  'Sign in required',
              message:
                  'Sign in as a provider to receive assistance requests.',
            )
          else
            StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream: RequestService()
                  .watchOpenRequests(),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons
                        .cloud_off_outlined,
                    title:
                        'Unable to load requests',
                    message:
                        'Check your connection and try again.',
                  );
                }

                if (!snapshot
                    .hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final userId =
                    FirebaseAuth
                        .instance
                        .currentUser!
                        .uid;

                final requests =
                    snapshot.data!.docs
                        .where(
                  (request) {
                    return _requestMatchesProvider(
                      request.data(),
                      userId,
                      services:
                          providerServices,
                    );
                  },
                ).toList();

                requests.sort(
                  (a, b) {
                    final aPriority =
                        isHighPriority(
                      a.data()[
                                  'priority']
                              as String? ??
                          'normal',
                    );

                    final bPriority =
                        isHighPriority(
                      b.data()[
                                  'priority']
                              as String? ??
                          'normal',
                    );

                    if (aPriority !=
                        bPriority) {
                      return aPriority
                          ? -1
                          : 1;
                    }

                    final aCreated =
                        (a.data()[
                                    'createdAt']
                                as Timestamp?)
                            ?.toDate();

                    final bCreated =
                        (b.data()[
                                    'createdAt']
                                as Timestamp?)
                            ?.toDate();

                    if (aCreated ==
                            null ||
                        bCreated ==
                            null) {
                      return 0;
                    }

                    return bCreated
                        .compareTo(
                      aCreated,
                    );
                  },
                );

                if (requests.isEmpty) {
                  return Container(
                    padding:
                        const EdgeInsets
                            .all(
                      RaSpace.xl,
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
                          alpha: .6,
                        ),
                      ),
                    ),
                    child:
                        const EmptyState(
                      icon: Icons
                          .inbox_outlined,
                      title:
                          'No new requests',
                      message:
                          'Matching driver requests will appear here in real time.',
                    ),
                  );
                }

                final request =
                    requests.first;

                return requestCard(
                  data:
                      request.data(),
                  requestId:
                      request.id,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ProviderHeroChip
    extends StatelessWidget {
  const _ProviderHeroChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: .14,
        ),
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
            icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(
            width: 6,
          ),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderHomeInfoRow
    extends StatelessWidget {
  const _ProviderHomeInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color:
              colors.primary,
        ),
        const SizedBox(
          width: RaSpace.sm,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme
                  .textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: value,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}