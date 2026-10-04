part of '../screens.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});
  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with WidgetsBindingObserver {
  bool online = true;
  bool wantsToBeOnline = true;
  String serviceRadius = '15 km from current location';
  List<String> providerServices = const [
    'Vehicle Towing',
    'Battery Jumpstart',
    'Flat Tyre',
    'General Mechanic',
  ];
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
    unawaited(AuthService().setProviderOnline(true));
    unawaited(_publishProviderLocation());
    profileSubscription = AuthService().watchCurrentProfile().listen((
      snapshot,
    ) {
      final savedServices = snapshot.data()?['services'] as List<dynamic>?;
      final savedRadius = snapshot.data()?['serviceRadius'] as String?;
      if (mounted) {
        setState(() {
          if (savedServices != null && savedServices.isNotEmpty) {
            providerServices = savedServices.whereType<String>().toList();
          }
          if (savedRadius != null && savedRadius.trim().isNotEmpty) {
            serviceRadius = savedRadius;
          }
        });
      }
    });
    openRequestsSubscription = RequestService().watchOpenRequests().listen(
      _handleOpenRequestUpdates,
    );
  }

  String get dashboardTitle {
    final towing = providerServices.contains('Vehicle Towing');
    final mechanic =
        providerServices.contains('General Mechanic') ||
        providerServices.contains('Flat Tyre') ||
        providerServices.contains('Battery Jumpstart');
    if (towing && !mechanic) return 'Tow Operator Dashboard';
    if (mechanic && !towing) return 'Mechanic Dashboard';
    return 'Provider Dashboard';
  }

  String get providerSpecialty {
    if (providerServices.isEmpty) return 'Roadside assistance professional';
    if (providerServices.length == 1) return providerServices.first;
    return '${providerServices.first} + ${providerServices.length - 1} more';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!signedIn) return;
    if (state == AppLifecycleState.resumed) {
      if (wantsToBeOnline) {
        setState(() => online = true);
        unawaited(AuthService().setProviderOnline(true));
        unawaited(_publishProviderLocation());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (online) {
        setState(() => online = false);
        unawaited(AuthService().setProviderOnline(false));
      }
    }
  }

  Future<void> _publishProviderLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
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
        ),
      );
      await AuthService().updateProviderDirectoryLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Nearby matching remains available for providers with older profiles.
    }
  }

  void _handleOpenRequestUpdates(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final matchingRequests = snapshot.docs.where((request) {
      return _requestMatchesProvider(
        request.data(),
        userId,
        services: providerServices,
      );
    }).toList();
    final currentIds = matchingRequests.map((request) => request.id).toSet();
    if (!openRequestsInitialized) {
      knownOpenRequestIds = currentIds;
      openRequestsInitialized = true;
      return;
    }
    final newRequests = matchingRequests
        .where((request) => !knownOpenRequestIds.contains(request.id))
        .toList();
    knownOpenRequestIds = currentIds;
    if (!mounted || !online || newRequests.isEmpty) return;

    final latest = newRequests.first.data();
    final driverName = latest['driverName'] as String? ?? 'A driver';
    final issue = latest['issue'] as String? ?? 'roadside assistance';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('$driverName needs $issue'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => push(context, const ProviderNotificationsScreen()),
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (signedIn && online) {
      unawaited(AuthService().setProviderOnline(false));
    }
    profileSubscription?.cancel();
    openRequestsSubscription?.cancel();
    super.dispose();
  }

  Widget requestCard({required Map<String, dynamic> data, String? requestId}) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final priority = data['priority'] as String? ?? 'normal';
    final highlighted = isHighPriority(priority);
    return Card(
      color: highlighted
          ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A2422)
                : const Color(0xFFFFF1EE))
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaRadius.lg),
        side: BorderSide(
          color: highlighted ? raDanger : raLine,
          width: highlighted ? 1.7 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (highlighted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RaSpace.md,
                  vertical: RaSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: raDangerPale,
                  borderRadius: BorderRadius.circular(RaRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: raDanger),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: Text(
                        requestPriorityLabel(priority).toUpperCase(),
                        style: RaText.label.copyWith(color: raDanger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RaSpace.md),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(RaRadius.sm),
              child: SizedBox(
                height: 150,
                child: MapMock(position: LatLng(latitude, longitude)),
              ),
            ),
            const SizedBox(height: RaSpace.md),
            SummaryRow(
              'Driver',
              data['driverName'] as String? ?? 'Nearby Driver',
            ),
            SummaryRow(
              'Vehicle',
              data['modelYear'] as String? ?? 'Vehicle details unavailable',
            ),
            SummaryRow('Issue', requestIssueLabel(data)),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Pinned location',
            ),
            SummaryRow(
              'Initial System Estimate',
              'Rs. ${data['estimatedCost'] ?? 2850}',
              strong: true,
            ),
            const SizedBox(height: RaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: raDanger,
                      side: const BorderSide(color: raLine),
                    ),
                    onPressed: () async {
                      if (requestId != null) {
                        await RequestService().rejectRequest(requestId);
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        if (requestId != null) {
                          final quote = await requestProviderQuote(
                            context,
                            data,
                          );
                          if (quote == null || !mounted) return;
                          await RequestService().acceptRequest(
                            requestId,
                            serviceFee: quote['serviceFee'] as int,
                            travelFee: quote['travelFee'] as int,
                            extraFee: quote['extraFee'] as int,
                            providerDistanceKm:
                                quote['providerDistanceKm'] as double,
                            quoteNotes: quote['quoteNotes'] as String,
                          );
                          data = Map<String, dynamic>.from(data)
                            ..addAll(quote)
                            ..['dispatchFee'] = quote['travelFee']
                            ..['estimatedCost'] =
                                (quote['serviceFee'] as int) +
                                (quote['travelFee'] as int) +
                                (quote['extraFee'] as int)
                            ..['status'] = 'accepted';
                        }
                        if (!mounted) return;
                        push(
                          context,
                          ProviderActiveJobScreen(
                            requestId: requestId,
                            requestData: data,
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        final activeJobExists = error.toString().contains(
                          'Complete your active job',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              activeJobExists
                                  ? 'Complete your active job before accepting another request.'
                                  : 'This request was cancelled or accepted by another provider.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Review & Quote'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(dashboardTitle),
      actions: [
        _ProviderRequestBadge(services: providerServices),
        IconButton(
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) replace(context, const WelcomeScreen());
          },
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF68A9DF), Color(0xFF4388C7)],
            ),
            borderRadius: BorderRadius.circular(RaRadius.md),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService().watchCurrentProfile(),
            builder: (context, snapshot) {
              final name =
                  snapshot.data?.data()?['displayName'] as String? ??
                  FirebaseAuth.instance.currentUser?.displayName ??
                  'Service Provider';
              return Column(
                children: [
                  Row(
                    children: [
                      _ProviderPresenceAvatar(name: name, online: online),
                      const SizedBox(width: RaSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RaSpace.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: online
                                    ? const Color(0xFFE7F8EF)
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(
                                  RaRadius.pill,
                                ),
                              ),
                              child: Text(
                                online ? 'ACTIVE' : 'OFFLINE',
                                style: TextStyle(
                                  color: online
                                      ? const Color(0xFF087A46)
                                      : Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              online ? providerSpecialty : 'Offline',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: online,
                        onChanged: (value) async {
                          setState(() {
                            online = value;
                            wantsToBeOnline = value;
                          });
                          await AuthService().setProviderOnline(value);
                          if (value) unawaited(_publishProviderLocation());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: RaSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(RaRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: RaSpace.sm),
                        const Text(
                          'Service radius',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          serviceRadius,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        _ProviderRealtimeStats(services: providerServices),
        const SizedBox(height: RaSpace.lg),
        _ProviderNewRequestsBanner(services: providerServices),
        const SizedBox(height: RaSpace.xxl),
        const _ProviderActiveJobsSection(),
        _ProviderServicesOverview(
          services: providerServices,
          serviceRadius: serviceRadius,
          onManage: () => push(context, const ProviderProfileScreen()),
        ),
        const SizedBox(height: RaSpace.xxl),
        const SectionTitle('Incoming Request'),
        const SizedBox(height: RaSpace.md),
        if (!online)
          const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'You are offline',
            message: 'Go online to receive nearby assistance requests.',
          )
        else if (FirebaseAuth.instance.currentUser == null)
          const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a provider to receive assistance requests.',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService().watchOpenRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load requests',
                  message: 'Check your connection and try again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final userId = FirebaseAuth.instance.currentUser!.uid;
              final requests = snapshot.data!.docs.where((request) {
                return _requestMatchesProvider(
                  request.data(),
                  userId,
                  services: providerServices,
                );
              }).toList();
              requests.sort((a, b) {
                final aPriority = isHighPriority(
                  a.data()['priority'] as String? ?? 'normal',
                );
                final bPriority = isHighPriority(
                  b.data()['priority'] as String? ?? 'normal',
                );
                if (aPriority == bPriority) return 0;
                return aPriority ? -1 : 1;
              });
              if (requests.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No new requests',
                  message: 'New requests will appear here in real time.',
                );
              }
              final request = requests.first;
              return requestCard(data: request.data(), requestId: request.id);
            },
          ),
      ],
    ),
  );
}
