part of '../../screens.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({
    super.key,
  });

  @override
  State<ProviderHomeScreen> createState() =>
      _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with WidgetsBindingObserver {
  bool online = false;
  bool savingPresence = false;
  bool publishingLocation = false;

  Map<String, dynamic> availability = <String, dynamic>{};

  List<String> providerServices = <String>[];

  String serviceRadius = 'Not configured';

  Timer? availabilityClock;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      directorySubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      profileSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      openRequestsSubscription;

  Set<String> knownOpenRequestIds = <String>{};

  bool openRequestsInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    availabilityClock = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );

    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      directorySubscription =
          FirebaseFirestore.instance
              .collection('providerDirectory')
              .doc(uid)
              .snapshots()
              .listen(
        (snapshot) {
          if (!mounted || savingPresence) {
            return;
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          setState(() {
            availability = data;
            online = data['online'] == true;
          });
        },
        onError: (_) {
          // Keep last known provider availability.
        },
      );
    }

    if (signedIn) {
      profileSubscription =
          AuthService()
              .watchCurrentProfile()
              .listen(
        (snapshot) {
          final data =
              snapshot.data();

          if (!mounted || data == null) {
            return;
          }

          final savedServices =
              (data['services']
                          as List<dynamic>? ??
                      const [])
                  .whereType<String>()
                  .toList();

          final savedRadius =
              data['serviceRadius']
                      ?.toString()
                      .trim() ??
                  '';

          setState(() {
            providerServices =
                savedServices;

            serviceRadius =
                savedRadius.isEmpty
                    ? 'Not configured'
                    : savedRadius;
          });
        },
        onError: (_) {
          // Existing profile data remains visible.
        },
      );

      openRequestsSubscription =
          RequestService()
              .watchOpenRequests()
              .listen(
        _handleOpenRequestUpdates,
        onError: (_) {
          // Dashboard streams handle their own errors.
        },
      );

      unawaited(
        _publishProviderLocation(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    availabilityClock?.cancel();
    directorySubscription?.cancel();
    profileSubscription?.cancel();
    openRequestsSubscription?.cancel();

    super.dispose();
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
      return 'No services configured';
    }

    if (providerServices.length == 1) {
      return providerServices.first;
    }

    return '${providerServices.first} + ${providerServices.length - 1} more';
  }

  Future<void> _publishProviderLocation() async {
    if (!signedIn ||
        publishingLocation) {
      return;
    }

    setState(() {
      publishingLocation = true;
    });

    try {
      await AuthService()
          .syncProviderDirectory();

      final enabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!enabled) {
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
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          timeLimit:
              Duration(seconds: 15),
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
      // Existing provider data remains usable if GPS is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          publishingLocation = false;
        });
      }
    }
  }

  Future<void> _setOnline(
    bool value,
  ) async {
    if (savingPresence) {
      return;
    }

    final previous = online;

    setState(() {
      online = value;
      savingPresence = true;
    });

    try {
      await AuthService()
          .setProviderOnline(value);

      if (value) {
        await _publishProviderLocation();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        online = previous;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update availability.',
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

  void _handleOpenRequestUpdates(
    QuerySnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    final userId =
        FirebaseAuth.instance
            .currentUser
            ?.uid;

    if (userId == null) {
      return;
    }

    final matching =
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

    final ids =
        matching
            .map(
              (request) =>
                  request.id,
            )
            .toSet();

    if (!openRequestsInitialized) {
      knownOpenRequestIds = ids;
      openRequestsInitialized = true;
      return;
    }

    final newRequests =
        matching.where(
      (request) =>
          !knownOpenRequestIds
              .contains(
            request.id,
          ),
    ).toList();

    knownOpenRequestIds = ids;

    if (!mounted ||
        _providerAvailabilityStatus(
              availability,
            ) !=
            'Online' ||
        newRequests.isEmpty) {
      return;
    }

    final request =
        newRequests.first.data();

    final driver =
        request['driverName']
                as String? ??
            'A driver';

    final issue =
        requestIssueLabel(
      request,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(
            seconds: 7,
          ),
          content: Text(
            '$driver needs $issue',
          ),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              push(
                context,
                const ProviderNotificationsScreen(),
              );
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final dark =
        theme.brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor:
          dark
              ? const Color(
                  0xFF07131E,
                )
              : const Color(
                  0xFFF5F8FC,
                ),
      body: !signedIn
          ? const SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.all(
                  20,
                ),
                child: EmptyState(
                  icon:
                      Icons.login_outlined,
                  title:
                      'Sign in required',
                  message:
                      'Sign in as a provider to access your dashboard.',
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh:
                    _publishProviderLocation,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(
                    parent:
                        BouncingScrollPhysics(),
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    32,
                  ),
                  children: [
                    _RaProviderTopHeader(
                      dashboardTitle:
                          dashboardTitle,
                      services:
                          providerServices,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _RaProviderHero(
                      online:
                          online,
                      savingPresence:
                          savingPresence,
                      publishingLocation:
                          publishingLocation,
                      speciality:
                          providerSpecialty,
                      availabilityLabel:
                          _providerAvailabilityStatus(
                        availability,
                      ),
                      onOnlineChanged:
                          _setOnline,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _RaProviderStats(
                      services:
                          providerServices,
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    const _RaProviderSectionHeader(
                      icon:
                          Icons.route_outlined,
                      title:
                          'Active work',
                      subtitle:
                          'Continue a roadside job already assigned to you.',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const _RaProviderActiveWork(),

                    const SizedBox(
                      height: 30,
                    ),

                    _RaProviderSectionHeader(
                      icon:
                          Icons
                              .notifications_active_outlined,
                      title:
                          'New requests',
                      subtitle:
                          'Roadside requests matching your configured services.',
                      action:
                          'View all',
                      onAction: () {
                        push(
                          context,
                          const ProviderNotificationsScreen(),
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _RaProviderRequestPreviewList(
                      services:
                          providerServices,
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    const _RaProviderSectionHeader(
                      icon:
                          Icons
                              .insights_outlined,
                      title:
                          'Performance',
                      subtitle:
                          'Live figures from completed RoadAssist jobs.',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const _RaProviderPerformance(),

                    const SizedBox(
                      height: 30,
                    ),

                    _RaProviderSectionHeader(
                      icon:
                          Icons
                              .home_repair_service_outlined,
                      title:
                          'Your services',
                      subtitle:
                          serviceRadius ==
                                  'Not configured'
                              ? 'Set your service area from Provider Profile.'
                              : 'Current service area: $serviceRadius',
                      action:
                          'Manage',
                      onAction: () {
                        push(
                          context,
                          const ProviderProfileScreen(),
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _RaProviderServices(
                      services:
                          providerServices,
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    const SafetyBox(),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============================================================
// TOP ROADASSIST HEADER
// ============================================================

class _RaProviderTopHeader
    extends StatelessWidget {
  const _RaProviderTopHeader({
    required this.dashboardTitle,
    required this.services,
  });

  final String dashboardTitle;
  final List<String> services;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const BrandMark(
            size: 42,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing:
                          -.55,
                    ),
                    children: [
                      TextSpan(
                        text: 'Road',
                        style: TextStyle(
                          color: theme
                              .colorScheme
                              .onSurface,
                        ),
                      ),
                      TextSpan(
                        text: 'Assist',
                        style: TextStyle(
                          color:
                              colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 1,
                ),
                Text(
                  dashboardTitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          _RaProviderHeaderAction(
            tooltip: 'Messages',
            child: const _ChatInbox(
              isProvider: true,
              buttonOnly: true,
            ),
          ),

          const SizedBox(
            width: 5,
          ),

          _RaProviderHeaderAction(
            tooltip:
                'New requests',
            child:
                _ProviderRequestBadge(
              services:
                  services,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderHeaderAction
    extends StatelessWidget {
  const _RaProviderHeaderAction({
    required this.tooltip,
    required this.child,
  });

  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 43,
        height: 43,
        alignment:
            Alignment.center,
        decoration: BoxDecoration(
          color: theme.brightness ==
                  Brightness.dark
              ? const Color(
                  0xFF0D1D2B,
                )
              : Colors.white,
          shape:
              BoxShape.circle,
          border: Border.all(
            color: theme
                .colorScheme
                .outlineVariant
                .withValues(
              alpha: .45,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

// ============================================================
// HERO / PROVIDER PROFILE + AVAILABILITY
// ============================================================

class _RaProviderHero
    extends StatelessWidget {
  const _RaProviderHero({
    required this.online,
    required this.savingPresence,
    required this.publishingLocation,
    required this.speciality,
    required this.availabilityLabel,
    required this.onOnlineChanged,
  });

  final bool online;
  final bool savingPresence;
  final bool publishingLocation;

  final String speciality;
  final String availabilityLabel;

  final ValueChanged<bool>
      onOnlineChanged;

  Uint8List? _photoBytes(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    try {
      final raw =
          value.contains(',')
              ? value.split(',').last
              : value;

      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream: signedIn
          ? AuthService()
              .watchCurrentProfile()
          : null,
      builder: (
        context,
        snapshot,
      ) {
        final data =
            snapshot.data?.data();

        final name =
            data?['displayName']
                    ?.toString()
                    .trim() ??
                FirebaseAuth.instance
                    .currentUser
                    ?.displayName
                    ?.trim() ??
                '';

        final displayName =
            name.isEmpty
                ? 'Service Provider'
                : name;

        final photo =
            _photoBytes(
          data?['photoData']
              ?.toString(),
        );

        return Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(
                        0xFF07579A,
                      ),
                      Color(
                        0xFF086F6B,
                      ),
                    ]
                  : const [
                      Color(
                        0xFF075FC0,
                      ),
                      Color(
                        0xFF078D82,
                      ),
                    ],
            ),
            borderRadius:
                BorderRadius.circular(
              26,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(
                      0xFF075BA8,
                    ).withValues(
                  alpha:
                      dark
                          ? .18
                          : .13,
                ),
                blurRadius: 28,
                offset:
                    const Offset(
                  0,
                  12,
                ),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -44,
                top: -52,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color: Colors.white
                        .withValues(
                      alpha: .04,
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 14,
                top: 18,
                child: Icon(
                  Icons
                      .directions_car_filled_outlined,
                  size: 86,
                  color: Colors.white
                      .withValues(
                    alpha: .055,
                  ),
                ),
              ),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior:
                            Clip.none,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(
                              2.5,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white,
                              shape:
                                  BoxShape.circle,
                            ),
                            child: photo ==
                                    null
                                ? ProfileInitials(
                                    name:
                                        displayName,
                                    radius: 29,
                                    background:
                                        Colors.white,
                                    foregroundColor:
                                        const Color(
                                      0xFF075BA8,
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 29,
                                    backgroundImage:
                                        MemoryImage(
                                      photo,
                                    ),
                                  ),
                          ),

                          Positioned(
                            right: -1,
                            bottom: 1,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration:
                                  BoxDecoration(
                                color: online
                                    ? const Color(
                                        0xFF38D78F,
                                      )
                                    : const Color(
                                        0xFFB7C1CC,
                                      ),
                                shape:
                                    BoxShape.circle,
                                border:
                                    Border.all(
                                  color:
                                      Colors.white,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        width: 13,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: GoogleFonts
                                  .plusJakartaSans(
                                color:
                                    Colors.white,
                                fontSize: 19,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                letterSpacing:
                                    -.4,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              speciality,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: GoogleFonts
                                  .plusJakartaSans(
                                color:
                                    Colors.white
                                        .withValues(
                                  alpha: .78,
                                ),
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: .11,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                      border:
                          Border.all(
                        color: Colors.white
                            .withValues(
                          alpha: .12,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration:
                              BoxDecoration(
                            color: Colors.white
                                .withValues(
                              alpha: .12,
                            ),
                            shape:
                                BoxShape.circle,
                          ),
                          child: Icon(
                            online
                                ? Icons
                                    .wifi_tethering_rounded
                                : Icons
                                    .wifi_off_rounded,
                            color:
                                Colors.white,
                            size: 19,
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
                                online
                                    ? 'Available for requests'
                                    : 'Currently offline',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  color:
                                      Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                publishingLocation &&
                                        online
                                    ? 'Updating your location…'
                                    : availabilityLabel,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  color:
                                      Colors.white
                                          .withValues(
                                    alpha: .70,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (savingPresence)
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(
                              horizontal: 13,
                            ),
                            child:
                                SizedBox.square(
                              dimension: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            ),
                          )
                        else
                          Switch(
                            value:
                                online,
                            onChanged:
                                onOnlineChanged,
                            activeTrackColor:
                                const Color(
                              0xFF66DBAE,
                            ),
                            activeThumbColor:
                                Colors.white,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// DASHBOARD STATS
// ============================================================

class _RaProviderStats
    extends StatelessWidget {
  const _RaProviderStats({
    required this.services,
  });

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: RequestService()
          .watchOpenRequests(),
      builder: (
        context,
        openSnapshot,
      ) {
        return StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: RequestService()
              .watchProviderRequests(),
          builder: (
            context,
            assignedSnapshot,
          ) {
            final userId =
                FirebaseAuth.instance
                    .currentUser
                    ?.uid;

            final newRequests =
                openSnapshot
                        .data
                        ?.docs
                        .where(
                          (
                            request,
                          ) =>
                              userId !=
                                  null &&
                              _requestMatchesProvider(
                                request
                                    .data(),
                                userId,
                                services:
                                    services,
                              ),
                        )
                        .length ??
                    0;

            final assigned =
                assignedSnapshot
                        .data
                        ?.docs ??
                    const [];

            final active =
                assigned.where(
              (request) {
                return const [
                  'accepted',
                  'en_route',
                  'arrived',
                ].contains(
                  request
                      .data()['status'],
                );
              },
            ).length;

            final completed =
                assigned.where(
              (request) =>
                  request
                      .data()['status'] ==
                  'completed',
            ).length;

            return Row(
              children: [
                Expanded(
                  child:
                      _RaProviderStatCard(
                    icon: Icons
                        .notifications_none_rounded,
                    value:
                        '$newRequests',
                    label: 'New',
                    tone:
                        const Color(
                      0xFF0A6CC7,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 9,
                ),

                Expanded(
                  child:
                      _RaProviderStatCard(
                    icon: Icons
                        .route_outlined,
                    value: '$active',
                    label:
                        'Active',
                    tone:
                        const Color(
                      0xFF137D9F,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 9,
                ),

                Expanded(
                  child:
                      _RaProviderStatCard(
                    icon: Icons
                        .task_alt_rounded,
                    value:
                        '$completed',
                    label:
                        'Completed',
                    tone:
                        raSuccess,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RaProviderStatCard
    extends StatelessWidget {
  const _RaProviderStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 112,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
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
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration:
                BoxDecoration(
              color: tone
                  .withValues(
                alpha: .09,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 19,
              color: tone,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            value,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 20,
              height: 1,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            label,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 11,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

class _RaProviderSectionHeader
    extends StatelessWidget {
  const _RaProviderSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 42,
          margin:
              const EdgeInsets.only(
            top: 1,
          ),
          decoration: BoxDecoration(
            color:
                colors.primary,
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color:
                        colors.primary,
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -.25,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                subtitle,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 11,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        if (action != null &&
            onAction != null) ...[
          const SizedBox(
            width: 5,
          ),
          TextButton(
            onPressed:
                onAction,
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  action!,
                ),
                const SizedBox(
                  width: 2,
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// ACTIVE WORK
// ============================================================

class _RaProviderActiveWork
    extends StatelessWidget {
  const _RaProviderActiveWork();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: signedIn
          ? RequestService()
              .watchProviderRequests()
          : null,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon:
                Icons.cloud_off_outlined,
            text:
                'Unable to load your active job.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(
            height: 160,
          );
        }

        final activeJobs =
            snapshot.data!.docs.where(
          (request) {
            return const [
              'accepted',
              'en_route',
              'arrived',
            ].contains(
              request
                  .data()['status'],
            );
          },
        ).toList();

        if (activeJobs.isEmpty) {
          return const _RaProviderActiveEmpty();
        }

        final job =
            activeJobs.first;

        final data =
            job.data();

        final driver =
            data['driverName']
                    ?.toString()
                    .trim() ??
                '';

        final location =
            data['locationLabel']
                    ?.toString()
                    .trim() ??
                data['location']
                    ?.toString()
                    .trim() ??
                '';

        final status =
            data['status']
                    ?.toString() ??
                'accepted';

        return _RaProviderActiveJob(
          driver: driver.isEmpty
              ? 'Driver'
              : driver,
          issue:
              requestIssueLabel(
            data,
          ),
          location:
              location.isEmpty
                  ? 'Location unavailable'
                  : location,
          status: status,
          onTap: () {
            push(
              context,
              ProviderActiveJobScreen(
                requestId:
                    job.id,
                requestData:
                    data,
              ),
            );
          },
        );
      },
    );
  }
}

class _RaProviderActiveEmpty
    extends StatelessWidget {
  const _RaProviderActiveEmpty();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 27,
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
          22,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
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
              color: colors.primary
                  .withValues(
                alpha: .075,
              ),
              borderRadius:
                  BorderRadius.circular(
                19,
              ),
            ),
            child: Icon(
              Icons
                  .route_outlined,
              color:
                  colors.primary,
              size: 30,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            'No active job',
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'An accepted roadside assistance job will appear here.',
            textAlign:
                TextAlign.center,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 12,
              height: 1.45,
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderActiveJob
    extends StatelessWidget {
  const _RaProviderActiveJob({
    required this.driver,
    required this.issue,
    required this.location,
    required this.status,
    required this.onTap,
  });

  final String driver;
  final String issue;
  final String location;
  final String status;

  final VoidCallback onTap;

  String get statusLabel {
    return switch (status) {
      'accepted' =>
        'Accepted',
      'en_route' =>
        'En route',
      'arrived' =>
        'Arrived',
      _ =>
        status.replaceAll(
          '_',
          ' ',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Material(
      color: theme.brightness ==
              Brightness.dark
          ? const Color(
              0xFF0D1D2B,
            )
          : Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        side: BorderSide(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(
            15,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Row(
                children: [
                  ProfileInitials(
                    name: driver,
                    radius: 23,
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
                          driver,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 14,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          issue,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 11,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  StatusPill(
                    label:
                        statusLabel,
                    tone:
                        RaTone.success,
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  11,
                ),
                decoration:
                    BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .25,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      Icons
                          .location_on_outlined,
                      size: 18,
                      color:
                          colors.primary,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 11,
                          height: 1.4,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              SizedBox(
                width: double.infinity,
                child:
                    FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons
                        .navigation_outlined,
                  ),
                  label: const Text(
                    'Continue Active Job',
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

// ============================================================
// NEW REQUESTS PREVIEW
// ============================================================

class _RaProviderRequestPreviewList
    extends StatelessWidget {
  const _RaProviderRequestPreviewList({
    required this.services,
  });

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: RequestService()
          .watchOpenRequests(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon:
                Icons.cloud_off_outlined,
            text:
                'Unable to load matching requests.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(
            height: 120,
          );
        }

        final userId =
            FirebaseAuth.instance
                .currentUser
                ?.uid;

        if (userId == null) {
          return const SizedBox
              .shrink();
        }

        final matches =
            snapshot.data!.docs
                .where(
                  (request) =>
                      _requestMatchesProvider(
                    request.data(),
                    userId,
                    services:
                        services,
                  ),
                )
                .take(2)
                .toList();

        if (matches.isEmpty) {
          return const _RaProviderRequestsEmpty();
        }

        return Column(
          children: [
            for (var index = 0;
                index <
                    matches.length;
                index++) ...[
              if (index > 0)
                const SizedBox(
                  height: 9,
                ),
              _RaProviderRequestCard(
                request:
                    matches[index],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RaProviderRequestsEmpty
    extends StatelessWidget {
  const _RaProviderRequestsEmpty();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        17,
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
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .075,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              Icons
                  .person_search_outlined,
              color:
                  colors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'No matching requests',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'New requests matching your services will appear automatically.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 11,
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
    );
  }
}

class _RaProviderRequestCard
    extends StatelessWidget {
  const _RaProviderRequestCard({
    required this.request,
  });

  final QueryDocumentSnapshot<
      Map<String, dynamic>> request;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final data =
        request.data();

    final driver =
        data['driverName']
                ?.toString()
                .trim() ??
            '';

    final driverName =
        driver.isEmpty
            ? 'Driver'
            : driver;

    final priority =
        data['priority']
                ?.toString() ??
            'normal';

    final location =
        data['locationLabel']
                ?.toString()
                .trim() ??
            data['location']
                ?.toString()
                .trim() ??
            '';

    return Material(
      color: theme.brightness ==
              Brightness.dark
          ? const Color(
              0xFF0D1D2B,
            )
          : Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        side: BorderSide(
          color:
              isHighPriority(
            priority,
          )
                  ? raGold.withValues(
                      alpha: .40,
                    )
                  : colors
                      .outlineVariant
                      .withValues(
                      alpha: .45,
                    ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          push(
            context,
            ProviderRequestDetailsScreen(
              requestId:
                  request.id,
              data: data,
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              ProfileInitials(
                name:
                    driverName,
                radius: 22,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driverName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                        if (isHighPriority(
                          priority,
                        ))
                          const StatusPill(
                            label:
                                'Priority',
                            tone:
                                RaTone.warning,
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      requestIssueLabel(
                        data,
                      ),
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w600,
                        color:
                            colors.primary,
                      ),
                    ),

                    if (location
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 6,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons
                                .location_on_outlined,
                            size: 15,
                            color: colors
                                .onSurfaceVariant,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 10.5,
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: colors
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PERFORMANCE
// ============================================================

class _RaProviderPerformance
    extends StatelessWidget {
  const _RaProviderPerformance();

  String _money(
    int value,
  ) {
    final negative =
        value < 0;

    final text =
        value.abs().toString();

    final output =
        StringBuffer();

    for (var index = 0;
        index < text.length;
        index++) {
      if (index > 0 &&
          (text.length - index) %
                  3 ==
              0) {
        output.write(',');
      }

      output.write(
        text[index],
      );
    }

    return 'Rs. ${negative ? '-' : ''}${output.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: RequestService()
          .watchProviderRequests(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon:
                Icons.analytics_outlined,
            text:
                'Unable to load performance data.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(
            height: 210,
          );
        }

        final completed =
            snapshot.data!.docs.where(
          (request) =>
              request
                  .data()['status'] ==
              'completed',
        ).toList();

        var totalRevenue = 0;

        final ratings =
            <double>[];

        for (final request
            in completed) {
          final data =
              request.data();

          final amount =
              (data['finalCost']
                          as num?)
                      ?.toInt() ??
                  (data['estimatedCost']
                          as num?)
                      ?.toInt() ??
                  0;

          totalRevenue += amount;

          final rating =
              (data['driverRating']
                      as num?)
                  ?.toDouble();

          if (rating != null &&
              rating > 0) {
            ratings.add(
              rating,
            );
          }
        }

        final averageRating =
            ratings.isEmpty
                ? null
                : ratings.reduce(
                      (
                        first,
                        second,
                      ) =>
                          first +
                          second,
                    ) /
                    ratings.length;

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
              22,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .45,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child:
                        _RaProviderPerformanceMetric(
                      icon: Icons
                          .payments_outlined,
                      label:
                          'Completed revenue',
                      value: _money(
                        totalRevenue,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child:
                        _RaProviderPerformanceMetric(
                      icon: Icons
                          .star_outline_rounded,
                      label:
                          'Driver rating',
                      value:
                          averageRating ==
                                  null
                              ? 'No ratings'
                              : '${averageRating.toStringAsFixed(1)} / 5',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              _RaProviderRevenueChart(
                jobs:
                    completed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RaProviderPerformanceMetric
    extends StatelessWidget {
  const _RaProviderPerformanceMetric({
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

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 100,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: .28,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
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
            height: 10,
          ),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 14,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            label,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 10.5,
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderRevenueChart
    extends StatelessWidget {
  const _RaProviderRevenueChart({
    required this.jobs,
  });

  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>> jobs;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final now =
        DateTime.now();

    final totals =
        List<int>.filled(
      7,
      0,
    );

    for (final job in jobs) {
      final data =
          job.data();

      final timestamp =
          data['completedAt']
              as Timestamp?;

      if (timestamp == null) {
        continue;
      }

      final completed =
          timestamp
              .toDate()
              .toLocal();

      final day =
          DateTime(
        completed.year,
        completed.month,
        completed.day,
      );

      final today =
          DateTime(
        now.year,
        now.month,
        now.day,
      );

      final difference =
          today
              .difference(day)
              .inDays;

      if (difference < 0 ||
          difference > 6) {
        continue;
      }

      final amount =
          (data['finalCost']
                      as num?)
                  ?.toInt() ??
              (data['estimatedCost']
                      as num?)
                  ?.toInt() ??
              0;

      totals[6 - difference] +=
          amount;
    }

    final maxValue =
        totals.fold<int>(
      0,
      (
        current,
        value,
      ) =>
          value > current
              ? value
              : current,
    );

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        13,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: .20,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
              letterSpacing:
                  .8,
              color: colors
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          SizedBox(
            height: 86,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,
              children: [
                for (var index = 0;
                    index <
                        totals.length;
                    index++)
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment:
                                  Alignment
                                      .bottomCenter,
                              child:
                                  AnimatedContainer(
                                duration:
                                    const Duration(
                                  milliseconds:
                                      250,
                                ),
                                width: 18,
                                height: maxValue ==
                                        0
                                    ? 5
                                    : 8 +
                                        (totals[index] /
                                                maxValue) *
                                            50,
                                decoration:
                                    BoxDecoration(
                                  color: totals[index] ==
                                          0
                                      ? colors
                                          .outlineVariant
                                      : colors
                                          .primary,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    999,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            _dayLabel(
                              now.subtract(
                                Duration(
                                  days: 6 -
                                      index,
                                ),
                              ),
                            ),
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 10,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(
    DateTime date,
  ) {
    const values = [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ];

    return values[
        date.weekday - 1];
  }
}

// ============================================================
// SERVICES
// ============================================================

class _RaProviderServices
    extends StatelessWidget {
  const _RaProviderServices({
    required this.services,
  });

  final List<String> services;

  IconData _iconFor(
    String service,
  ) {
    return switch (service) {
      'Vehicle Towing' =>
        Icons.fire_truck_outlined,
      'Battery Jumpstart' =>
        Icons
            .battery_charging_full_rounded,
      'Flat Tyre' =>
        Icons.tire_repair_outlined,
      'General Mechanic' =>
        Icons.car_repair_outlined,
      _ =>
        Icons
            .home_repair_service_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      final colors =
          Theme.of(context)
              .colorScheme;

      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(
          17,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
                      .brightness ==
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
            color: colors
                .outlineVariant
                .withValues(
              alpha: .45,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration:
                  BoxDecoration(
                color: colors.primary
                    .withValues(
                  alpha: .08,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),
              child: Icon(
                Icons
                    .home_repair_service_outlined,
                color:
                    colors.primary,
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
                    'Services not configured',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 13,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Add the roadside services you provide from your profile.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 11,
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
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final twoColumns =
            constraints.maxWidth >=
                330;

        final tileWidth =
            twoColumns
                ? (constraints.maxWidth -
                        9) /
                    2
                : constraints.maxWidth;

        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final service
                in services)
              SizedBox(
                width:
                    tileWidth,
                child:
                    _RaProviderServiceTile(
                  icon:
                      _iconFor(
                    service,
                  ),
                  label:
                      service,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RaProviderServiceTile
    extends StatelessWidget {
  const _RaProviderServiceTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 86,
      ),
      padding:
          const EdgeInsets.all(
        13,
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
          18,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color:
                  colors.primary,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 11.5,
                height: 1.3,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING CARD
// ============================================================

class _RaProviderLoadingCard
    extends StatelessWidget {
  const _RaProviderLoadingCard({
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      height: height,
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
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: const Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }
}