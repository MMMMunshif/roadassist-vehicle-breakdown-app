part of '../screens.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String locationLabel = 'Galle Road, Colombo 03, Sri Lanka';
  bool updatingLocation = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  locationProfileSubscription;

  @override
  void initState() {
    super.initState();
    if (signedIn) {
      locationProfileSubscription = AuthService().watchCurrentProfile().listen((
        snapshot,
      ) {
        final saved = snapshot.data()?['currentLocationLabel'] as String?;
        if (mounted && saved != null && saved.trim().isNotEmpty) {
          setState(() => locationLabel = saved);
        }
      });
    }
  }

  @override
  void dispose() {
    locationProfileSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveLocation(
    String label, {
    double? latitude,
    double? longitude,
  }) async {
    setState(() => locationLabel = label);
    if (signedIn) {
      await AuthService().updateCurrentProfile({
        'currentLocationLabel': label,
        'currentLatitude': ?latitude,
        'currentLongitude': ?longitude,
      });
    }
  }

  Future<void> useCurrentHomeLocation() async {
    setState(() => updatingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission is required.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      var label =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          label =
              [
                    place.street,
                    place.locality,
                    place.administrativeArea,
                    place.country,
                  ]
                  .whereType<String>()
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
        }
      } catch (_) {
        // Browser geocoding may be unavailable; coordinates remain accurate.
      }
      await saveLocation(
        label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location updated.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update location: $error')),
        );
    } finally {
      if (mounted) setState(() => updatingLocation = false);
    }
  }

  Future<void> enterLocationManually() async {
    final controller = TextEditingController(text: locationLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Current Location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street, city or landmark',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) await saveLocation(value);
  }

  Future<void> changeHomeLocation() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const IconBadge(Icons.my_location_outlined),
              title: const Text('Use current GPS location'),
              onTap: () => Navigator.pop(context, 'gps'),
            ),
            ListTile(
              leading: const IconBadge(Icons.edit_location_alt_outlined),
              title: const Text('Enter location manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'gps') await useCurrentHomeLocation();
    if (action == 'manual') await enterLocationManually();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const ServiceNotice(),
        DashboardHeader(
          child: Column(
            children: [
              Row(
                children: [
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser == null
                        ? null
                        : AuthService().watchCurrentProfile(),
                    builder: (context, snapshot) {
                      final name =
                          snapshot.data?.data()?['displayName'] as String? ??
                          FirebaseAuth.instance.currentUser?.displayName ??
                          'Driver';
                      final photoData =
                          snapshot.data?.data()?['photoData'] as String?;
                      return Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: photoData == null || photoData.isEmpty
                            ? ProfileInitials(
                                name: name,
                                radius: 24,
                                background: Colors.white,
                              )
                            : ClipOval(
                                child: Image.memory(
                                  base64Decode(photoData),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseAuth.instance.currentUser == null
                              ? null
                              : AuthService().watchCurrentProfile(),
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.data()?['displayName']
                                    as String? ??
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'Driver';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WELCOME BACK',
                                  style: RaText.eyebrow.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  const _ChatInbox(isProvider: false, buttonOnly: true),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: signedIn
                        ? RequestService().watchDriverRequests()
                        : null,
                    builder: (context, snapshot) {
                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: signedIn
                            ? AuthService().watchCurrentProfile()
                            : null,
                        builder: (context, profileSnapshot) {
                          final seenAt =
                              profileSnapshot.data
                                      ?.data()?['notificationsSeenAt']
                                  as Timestamp?;
                          final count =
                              snapshot.data?.docs.where((doc) {
                                final updatedAt =
                                    doc.data()['updatedAt'] as Timestamp?;
                                return doc.data()['status'] != 'searching' &&
                                    (seenAt == null ||
                                        (updatedAt?.compareTo(seenAt) ?? 1) >
                                            0);
                              }).length ??
                              0;
                          return Badge(
                            isLabelVisible: count > 0,
                            label: Text(count > 9 ? '9+' : '$count'),
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 44),
                              ),
                              tooltip: 'Notifications',
                              onPressed: () {
                                if (signedIn) {
                                  push(
                                    context,
                                    const DriverNotificationsScreen(),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sign in to view request notifications.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.notifications_none),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.md),
              Container(
                padding: const EdgeInsets.all(RaSpace.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: updatingLocation ? null : changeHomeLocation,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  child: Row(
                    children: [
                      const IconBadge(Icons.location_on_outlined, size: 36),
                      const SizedBox(width: RaSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT LOCATION',
                              style: TextStyle(
                                color: raMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationLabel,
                              style: RaText.title.copyWith(color: raInk),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (updatingLocation)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.edit_location_alt_outlined,
                          color: raBlue,
                          size: 21,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(RaSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(RaSpace.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF182733)
                      : const Color(0xFFF3F9FE),
                  borderRadius: BorderRadius.circular(RaRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: raDangerPale,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sos_outlined,
                        color: raDanger,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: RaSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need roadside help?',
                            style: RaText.title.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send your location to nearby providers.',
                            style: RaText.caption.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    FilledButton(
                      onPressed: () =>
                          push(context, const AssistanceTypeScreen()),
                      style: FilledButton.styleFrom(
                        backgroundColor: raDanger,
                        minimumSize: const Size(88, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Get Help'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RaSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.person_search_outlined,
                      label: 'Providers',
                      onTap: () =>
                          push(context, const ProviderDirectoryScreen()),
                    ),
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Requests',
                      onTap: () => push(context, const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.support_agent_outlined,
                      label: 'Support',
                      onTap: () =>
                          push(context, const SupportScreen(isProvider: false)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.xxl),
              SectionTitle(
                'Nearby Assistance',
                action: 'See All',
                onAction: () => push(context, const ProviderDirectoryScreen()),
              ),
              const SizedBox(height: RaSpace.md),
              const _NearbyProvidersPreview(),
              const SizedBox(height: RaSpace.xxl),
              const SectionTitle('My Requests'),
              const SizedBox(height: RaSpace.md),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: signedIn
                    ? RequestService().watchDriverRequests()
                    : null,
                builder: (context, snapshot) {
                  if (!signedIn) {
                    return const InlineMessage(
                      icon: Icons.login_outlined,
                      text: 'Sign in to view and track your requests.',
                    );
                  }
                  if (snapshot.hasError) {
                    return const InlineMessage(
                      icon: Icons.cloud_off_outlined,
                      text: 'Unable to load your requests.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const InlineMessage(
                      icon: Icons.receipt_long_outlined,
                      text: 'No assistance requests yet.',
                    );
                  }
                  final requests = snapshot.data!.docs;
                  final active = requests.where((request) {
                    return const [
                      'searching',
                      'accepted',
                      'en_route',
                      'arrived',
                    ].contains(request.data()['status']);
                  });
                  return _DriverRequestPreview(
                    request: active.isEmpty ? requests.first : active.first,
                  );
                },
              ),
              const SizedBox(height: RaSpace.xxl),
              const Text('Emergency Contacts', style: RaText.headline),
              const SizedBox(height: RaSpace.md),
              Card(
                child: Column(
                  children: [
                    ContactTile(
                      'Police Emergency',
                      '119',
                      onTap: () => showCallPrompt(
                        context,
                        name: 'Police Emergency',
                        number: '119',
                      ),
                    ),
                    const Divider(height: 1),
                    ContactTile(
                      'Suwa Seriya Ambulance',
                      '1990',
                      onTap: () => showCallPrompt(
                        context,
                        name: 'Suwa Seriya Ambulance',
                        number: '1990',
                      ),
                    ),
                    const Divider(height: 1),
                    const _DriverEmergencyContactTile(),
                  ],
                ),
              ),
              const SizedBox(height: RaSpace.xl),
            ],
          ),
        ),
      ],
    ),
  );
}
