part of '../../screens.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
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

    availabilityClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      directorySubscription = FirebaseFirestore.instance
          .collection('providerDirectory')
          .doc(uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted || savingPresence) {
                return;
              }

              final data = snapshot.data() ?? <String, dynamic>{};

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
      profileSubscription = AuthService().watchCurrentProfile().listen(
        (snapshot) {
          final data = snapshot.data();

          if (!mounted || data == null) {
            return;
          }

          final savedServices = [
            ...(data['services'] as List<dynamic>? ?? const []),
            ...(data['additionalServiceNames'] as List<dynamic>? ?? const []),
          ].whereType<String>().toList();

          final savedRadius = data['serviceRadius']?.toString().trim() ?? '';

          setState(() {
            providerServices = savedServices;

            serviceRadius = savedRadius.isEmpty
                ? 'Not configured'
                : savedRadius;
          });
        },
        onError: (_) {
          // Existing profile data remains visible.
        },
      );

      openRequestsSubscription = RequestService().watchOpenRequests().listen(
        _handleOpenRequestUpdates,
        onError: (_) {
          // Dashboard streams handle their own errors.
        },
      );

      unawaited(_publishProviderLocation());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    availabilityClock?.cancel();
    directorySubscription?.cancel();
    profileSubscription?.cancel();
    openRequestsSubscription?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && signedIn && online) {
      unawaited(_publishProviderLocation());
    }
  }

  String get dashboardTitle {
    final towing = providerServices.contains('Vehicle Towing');

    final mechanic =
        providerServices.contains('General Mechanic') ||
        providerServices.contains('Flat Tyre') ||
        providerServices.contains('Battery Jumpstart');

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
    if (!signedIn || publishingLocation) {
      return;
    }

    setState(() {
      publishingLocation = true;
    });

    try {
      await AuthService().syncProviderDirectory();

      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await AuthService().updateProviderDirectoryLocation(
        latitude: position.latitude,
        longitude: position.longitude,
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

  Future<void> _setOnline(bool value) async {
    if (savingPresence) {
      return;
    }

    final previous = online;

    setState(() {
      online = value;
      savingPresence = true;
    });

    try {
      await AuthService().setProviderOnline(value);

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update availability.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingPresence = false;
        });
      }
    }
  }

  void _handleOpenRequestUpdates(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return;
    }

    final matching = snapshot.docs.where((request) {
      return _requestMatchesProvider(
        request.data(),
        userId,
        services: providerServices,
      );
    }).toList();

    final ids = matching.map((request) => request.id).toSet();

    if (!openRequestsInitialized) {
      knownOpenRequestIds = ids;
      openRequestsInitialized = true;
      return;
    }

    final newRequests = matching
        .where((request) => !knownOpenRequestIds.contains(request.id))
        .toList();

    knownOpenRequestIds = ids;

    if (!mounted ||
        _providerAvailabilityStatus(availability) != 'Online' ||
        newRequests.isEmpty) {
      return;
    }

    final request = newRequests.first.data();

    final driver = request['driverName'] as String? ?? 'A driver';

    final issue = requestIssueLabel(request);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Text('$driver needs $issue'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              _openProviderRequests(context);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;

    return RaProviderScaffold(
      backgroundColor: dark ? const Color(0xFF07131E) : const Color(0xFFF5F8FC),
      body: !signedIn
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.login_outlined,
                  title: 'Sign in required',
                  message: 'Sign in as a provider to access your dashboard.',
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _publishProviderLocation,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _RaProviderTopHeader(
                      dashboardTitle: dashboardTitle,
                      services: providerServices,
                    ),

                    const SizedBox(height: 16),

                    _RaProviderHero(
                      online: online,
                      savingPresence: savingPresence,
                      publishingLocation: publishingLocation,
                      speciality: providerSpecialty,
                      availabilityLabel: _providerAvailabilityStatus(
                        availability,
                      ),
                      onOnlineChanged: _setOnline,
                    ),

                    const SizedBox(height: 14),

                    _RaProviderStats(services: providerServices),

                    const SizedBox(height: 20),

                    _RaProviderSectionHeader(
                      action: 'View all',
                      onAction: () =>
                          push(context, const _RaProviderActiveWorkScreen()),
                      icon: Icons.route_outlined,
                      title: 'Active work',
                      subtitle:
                          'Continue a roadside job already assigned to you.',
                    ),

                    const SizedBox(height: 12),

                    const _RaProviderActiveWork(),

                    const SizedBox(height: 20),

                    _RaProviderSectionHeader(
                      icon: Icons.notifications_active_outlined,
                      title: 'New requests',
                      subtitle:
                          'Roadside requests matching your configured services.',
                      action: 'View all',
                      onAction: () {
                        _openProviderRequests(context);
                      },
                    ),

                    const SizedBox(height: 12),

                    if (_providerAvailabilityStatus(availability) != 'Online')
                      const RaProviderEmptyCard(
                        icon: Icons.notifications_none_rounded,
                        title: 'Go online to see matching requests',
                        message:
                            'Requests match your services and availability.',
                      )
                    else
                      _RaProviderRequestPreviewList(services: providerServices),

                    const SizedBox(height: 20),

                    const _RaProviderSectionHeader(
                      icon: Icons.insights_outlined,
                      title: 'Performance',
                      subtitle: 'Live figures from completed RoadAssist jobs.',
                    ),

                    const SizedBox(height: 12),

                    const _RaProviderPerformance(),

                    const SizedBox(height: 20),

                    _RaProviderSectionHeader(
                      icon: Icons.home_repair_service_outlined,
                      title: 'Your services',
                      subtitle: serviceRadius == 'Not configured'
                          ? 'Set your service area from Provider Profile.'
                          : 'Current service area: $serviceRadius',
                      action: 'Manage',
                      onAction: () {
                        _openProviderProfile(context);
                      },
                    ),

                    const SizedBox(height: 12),

                    _RaProviderServices(services: providerServices),

                    const SizedBox(height: 26),

                    const RaProviderEmptyCard(
                      icon: Icons.shield_outlined,
                      title: 'Stay safe on the road',
                      message:
                          'Wear visible gear and follow local safety guidelines.',
                    ),
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

class _RaProviderTopHeader extends StatelessWidget {
  const _RaProviderTopHeader({
    required this.dashboardTitle,
    required this.services,
  });
  final String dashboardTitle;
  final List<String> services;
  @override
  Widget build(BuildContext context) => RaProviderHeader(
    notifications: _ProviderRequestBadge(services: services),
  );
}

class _RaProviderHero extends StatelessWidget {
  const _RaProviderHero({
    required this.online,
    required this.savingPresence,
    required this.publishingLocation,
    required this.speciality,
    required this.availabilityLabel,
    required this.onOnlineChanged,
  });
  final bool online, savingPresence, publishingLocation;
  final String speciality, availabilityLabel;
  final ValueChanged<bool> onOnlineChanged;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: signedIn ? AuthService().watchCurrentProfile() : null,
    builder: (context, snapshot) {
      final data = snapshot.data?.data();
      final name =
          data?['displayName']?.toString().trim() ??
          FirebaseAuth.instance.currentUser?.displayName?.trim() ??
          '';
      final displayName = name.isEmpty ? 'Service Provider' : name;
      Widget avatar = ProfileInitials(name: displayName, radius: 25);
      try {
        final photo = data?['photoData']?.toString() ?? '';
        if (photo.isNotEmpty) {
          avatar = CircleAvatar(
            radius: 25,
            backgroundImage: MemoryImage(base64Decode(photo.split(',').last)),
          );
        }
      } catch (_) {
        /* Retain initials if a stored photo cannot be decoded. */
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good morning, $displayName',
            style: _providerText(context, muted: true),
          ),
          const SizedBox(height: 4),
          Text(
            'Ready to help today?',
            style: _providerText(context, size: 24, weight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          RaProviderIdentityCard(
            avatar: avatar,
            speciality: speciality,
            online: online,
            busy: savingPresence,
            onChanged: onOnlineChanged,
            status: publishingLocation && online
                ? 'Updating your location…'
                : online
                ? availabilityLabel
                : 'Currently offline',
          ),
        ],
      );
    },
  );
}

class _RaProviderStats extends StatelessWidget {
  const _RaProviderStats({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchOpenRequests(),
      builder: (context, openSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: RequestService().watchProviderRequests(),
          builder: (context, assignedSnapshot) {
            final userId = FirebaseAuth.instance.currentUser?.uid;

            final newRequests =
                openSnapshot.data?.docs
                    .where(
                      (request) =>
                          userId != null &&
                          _requestMatchesProvider(
                            request.data(),
                            userId,
                            services: services,
                          ),
                    )
                    .length ??
                0;

            final assigned = assignedSnapshot.data?.docs ?? const [];

            final active = assigned.where((request) {
              return const [
                'accepted',
                'en_route',
                'arrived',
              ].contains(request.data()['status']);
            }).length;

            final completed = assigned
                .where((request) => request.data()['status'] == 'completed')
                .length;

            return Row(
              children: [
                Expanded(
                  child: _RaProviderStatCard(
                    icon: Icons.notifications_none_rounded,
                    value: '$newRequests',
                    label: 'New',
                    tone: const Color(0xFF0A6CC7),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: _RaProviderStatCard(
                    icon: Icons.route_outlined,
                    value: '$active',
                    label: 'Active',
                    tone: const Color(0xFF137D9F),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: _RaProviderStatCard(
                    icon: Icons.task_alt_rounded,
                    value: '$completed',
                    label: 'Completed',
                    tone: raSuccess,
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

class _RaProviderStatCard extends StatelessWidget {
  const _RaProviderStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });
  final IconData icon;
  final String value, label;
  final Color tone;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final iconWidget = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: tone),
        );
        final figures = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _providerText(context, size: 11, muted: true)),
            Text(
              value,
              style: _providerText(context, size: 19, weight: FontWeight.w800),
            ),
          ],
        );
        if (constraints.maxWidth < 80 ||
            MediaQuery.textScalerOf(context).scale(14) > 19) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [iconWidget, const SizedBox(height: 6), figures],
          );
        }
        return Row(
          children: [
            iconWidget,
            const SizedBox(width: 6),
            Expanded(child: figures),
          ],
        );
      },
    ),
  );
}

class _RaProviderSectionHeader extends StatelessWidget {
  const _RaProviderSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title, subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => RaProviderSection(
    title: title,
    action: action,
    onAction: onAction,
    caption: title == 'Performance' ? 'Last 7 days' : null,
  );
}

class _RaProviderActiveWork extends StatelessWidget {
  const _RaProviderActiveWork();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchProviderRequests() : null,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Unable to load your active job.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(height: 160);
        }

        final activeJobs = snapshot.data!.docs.where((request) {
          return const [
            'accepted',
            'en_route',
            'arrived',
          ].contains(request.data()['status']);
        }).toList();

        if (activeJobs.isEmpty) {
          return const _RaProviderActiveEmpty();
        }

        final job = activeJobs.first;

        final data = job.data();

        final driver = data['driverName']?.toString().trim() ?? '';

        final location =
            data['locationLabel']?.toString().trim() ??
            data['location']?.toString().trim() ??
            '';

        final status = data['status']?.toString() ?? 'accepted';

        return _RaProviderActiveJob(
          driver: driver.isEmpty ? 'Driver' : driver,
          issue: requestIssueLabel(data),
          location: location.isEmpty ? 'Location unavailable' : location,
          status: status,
          onTap: () {
            push(
              context,
              ProviderActiveJobScreen(requestId: job.id, requestData: data),
            );
          },
        );
      },
    );
  }
}

class _RaProviderActiveEmpty extends StatelessWidget {
  const _RaProviderActiveEmpty();
  @override
  Widget build(BuildContext context) => const RaProviderEmptyCard(
    icon: Icons.route_outlined,
    title: 'No active job',
    message: 'Your active job will appear here when you accept a request.',
  );
}

class _RaProviderActiveJob extends StatelessWidget {
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
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      _ => status.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Material(
      color: _providerSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileInitials(name: driver, radius: 23),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          issue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  StatusPill(label: statusLabel, tone: RaTone.success),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Continue Active Job'),
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

class _RaProviderRequestPreviewList extends StatelessWidget {
  const _RaProviderRequestPreviewList({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchOpenRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Unable to load matching requests.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(height: 120);
        }

        final userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId == null) {
          return const SizedBox.shrink();
        }

        final matches = snapshot.data!.docs
            .where(
              (request) => _requestMatchesProvider(
                request.data(),
                userId,
                services: services,
              ),
            )
            .take(2)
            .toList();

        if (matches.isEmpty) {
          return const _RaProviderRequestsEmpty();
        }

        return Column(
          children: [
            for (var index = 0; index < matches.length; index++) ...[
              if (index > 0) const SizedBox(height: 9),
              _RaProviderRequestCard(request: matches[index]),
            ],
          ],
        );
      },
    );
  }
}

class _RaProviderRequestsEmpty extends StatelessWidget {
  const _RaProviderRequestsEmpty();
  @override
  Widget build(BuildContext context) => const RaProviderEmptyCard(
    icon: Icons.notifications_none_rounded,
    title: 'No matching requests',
    message: 'New requests matching your services will appear here.',
  );
}

class _RaProviderRequestCard extends StatelessWidget {
  const _RaProviderRequestCard({required this.request});

  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final data = request.data();

    final driver = data['driverName']?.toString().trim() ?? '';

    final driverName = driver.isEmpty ? 'Driver' : driver;

    final priority = data['priority']?.toString() ?? 'normal';

    final location =
        data['locationLabel']?.toString().trim() ??
        data['location']?.toString().trim() ??
        '';

    return Material(
      color: _providerSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: isHighPriority(priority)
              ? raGold.withValues(alpha: .40)
              : colors.outlineVariant.withValues(alpha: .45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          push(
            context,
            ProviderRequestDetailsScreen(requestId: request.id, data: data),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileInitials(name: driverName, radius: 22),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isHighPriority(priority))
                          const StatusPill(
                            label: 'Priority',
                            tone: RaTone.warning,
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      requestIssueLabel(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),

                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 5),

              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
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

class _RaProviderPerformance extends StatelessWidget {
  const _RaProviderPerformance();

  String _money(int value) {
    final negative = value < 0;

    final text = value.abs().toString();

    final output = StringBuffer();

    for (var index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 == 0) {
        output.write(',');
      }

      output.write(text[index]);
    }

    return 'Rs. ${negative ? '-' : ''}${output.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchProviderRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.analytics_outlined,
            text: 'Unable to load performance data.',
          );
        }

        if (!snapshot.hasData) {
          return const _RaProviderLoadingCard(height: 210);
        }

        final completed = snapshot.data!.docs
            .where((request) => request.data()['status'] == 'completed')
            .toList();

        var totalRevenue = 0;

        final ratings = <double>[];

        for (final request in completed) {
          final data = request.data();

          final amount =
              (data['finalCost'] as num?)?.toInt() ??
              (data['estimatedCost'] as num?)?.toInt() ??
              0;

          totalRevenue += amount;

          final rating = (data['driverRating'] as num?)?.toDouble();

          if (rating != null && rating > 0) {
            ratings.add(rating);
          }
        }

        final averageRating = ratings.isEmpty
            ? null
            : ratings.reduce((first, second) => first + second) /
                  ratings.length;

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _providerSurface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .45),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _RaProviderPerformanceMetric(
                      icon: Icons.payments_outlined,
                      label: 'Completed revenue',
                      value: _money(totalRevenue),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: _RaProviderPerformanceMetric(
                      icon: Icons.star_outline_rounded,
                      label: 'Driver rating',
                      value: averageRating == null
                          ? 'No ratings'
                          : '${averageRating.toStringAsFixed(1)} / 5',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              _RaProviderRevenueChart(jobs: completed),
            ],
          ),
        );
      },
    );
  }
}

class _RaProviderPerformanceMetric extends StatelessWidget {
  const _RaProviderPerformanceMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 7),
        Text(
          value,
          style: _providerText(context, size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(label, style: _providerText(context, size: 12, muted: true)),
      ],
    ),
  );
}

class _RaProviderRevenueChart extends StatelessWidget {
  const _RaProviderRevenueChart({required this.jobs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final now = DateTime.now();

    final totals = List<int>.filled(7, 0);

    for (final job in jobs) {
      final data = job.data();

      final timestamp = data['completedAt'] as Timestamp?;

      if (timestamp == null) {
        continue;
      }

      final completed = timestamp.toDate().toLocal();

      final day = DateTime(completed.year, completed.month, completed.day);

      final today = DateTime(now.year, now.month, now.day);

      final difference = today.difference(day).inDays;

      if (difference < 0 || difference > 6) {
        continue;
      }

      final amount =
          (data['finalCost'] as num?)?.toInt() ??
          (data['estimatedCost'] as num?)?.toInt() ??
          0;

      totals[6 - difference] += amount;
    }

    final maxValue = totals.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 86 + (MediaQuery.textScalerOf(context).scale(10) - 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < totals.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 18,
                                height: maxValue == 0
                                    ? 5
                                    : 8 + (totals[index] / maxValue) * 50,
                                decoration: BoxDecoration(
                                  color: totals[index] == 0
                                      ? colors.outlineVariant
                                      : colors.primary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _dayLabel(now.subtract(Duration(days: 6 - index))),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
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

  String _dayLabel(DateTime date) {
    const values = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return values[date.weekday - 1];
  }
}

// ============================================================
// SERVICES
// ============================================================

class _RaProviderServices extends StatelessWidget {
  const _RaProviderServices({required this.services});

  final List<String> services;

  IconData _iconFor(String service) {
    return switch (service) {
      'Vehicle Towing' => Icons.fire_truck_outlined,
      'Battery Jumpstart' => Icons.battery_charging_full_rounded,
      'Flat Tyre' => Icons.tire_repair_outlined,
      'General Mechanic' => Icons.car_repair_outlined,
      _ => Icons.home_repair_service_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      final colors = Theme.of(context).colorScheme;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0D2237)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.home_repair_service_outlined,
                color: colors.primary,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Services not configured',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Add the roadside services you provide from your profile.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
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
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 340
            ? 3
            : constraints.maxWidth >= 270
            ? 2
            : 1;
        final tileWidth = (constraints.maxWidth - 9 * (columns - 1)) / columns;

        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final service in services)
              SizedBox(
                width: tileWidth,
                child: _RaProviderServiceTile(
                  icon: _iconFor(service),
                  label: service,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RaProviderServiceTile extends StatelessWidget {
  const _RaProviderServiceTile({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: _providerText(context, size: 12, weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _RaProviderLoadingCard extends StatelessWidget {
  const _RaProviderLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _providerSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _RaProviderActiveWorkScreen extends StatelessWidget {
  const _RaProviderActiveWorkScreen();
  @override
  Widget build(BuildContext context) => RaProviderScaffold(
    appBar: AppBar(title: const Text('Active work')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _RaProviderActiveWork(),
    ),
  );
}
