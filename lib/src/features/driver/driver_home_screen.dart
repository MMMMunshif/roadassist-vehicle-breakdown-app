part of '../../screens.dart';

// Home presentation primitives inherit the shared light/dark theme.
class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _HomeSurface(
      onTap: onTap,
      child: Column(
        children: [
          Badge(
            isLabelVisible: count != null && count! > 0,
            label: Text(count != null && count! > 99 ? '99+' : '$count'),
            child: Icon(icon, size: 28, color: colors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle(this.title, {this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

Widget _homeContent(BuildContext context, Widget child) => child;

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String locationLabel = 'Galle Road, Colombo 03, Sri Lanka';
  bool updatingLocation = false;
  Stream<List<Vehicle>>? homeVehicles;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  locationProfileSubscription;

  @override
  void initState() {
    super.initState();
    if (signedIn) {
      homeVehicles = VehicleService().watchVehicles();
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

  // ---------------------------------------------------------------------------
  // LOGIC (unchanged)
  // ---------------------------------------------------------------------------

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
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update location: $error')),
        );
      }
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

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: signedIn ? AuthService().watchCurrentProfile() : null,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name =
            data?['displayName'] as String? ??
            (firebaseReady
                ? FirebaseAuth.instance.currentUser?.displayName
                : null) ??
            'Driver';
        final photo = data?['photoData'] as String?;
        Widget avatar = ProfileInitials(name: name, radius: 24);
        if (photo != null && photo.isNotEmpty) {
          try {
            avatar = ClipOval(
              child: Image.memory(
                base64Decode(photo),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) =>
                    ProfileInitials(name: name, radius: 24),
              ),
            );
          } on FormatException {
            /* Preserve a readable fallback for malformed stored photos. */
          }
        }
        return Column(
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/images/roadassist_home_scene.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withValues(alpha: .94),
                          theme.scaffoldBackgroundColor.withValues(alpha: .18),
                        ],
                        stops: const [0, .48, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_road_rounded,
                            color: colors.secondary,
                            size: 38,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Road',
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                  TextSpan(
                                    text: 'Assist',
                                    style: TextStyle(color: colors.primary),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          avatar,
                          _buildNotificationButton(
                            context,
                            data?['notificationsSeenAt'] as Timestamp?,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '$greeting,',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: .85,
                        child: Text(
                          name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 32,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 270,
                        child: Text(
                          "Stay safe. We're here whenever you need to get back on the road.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSavedVehicleCard(
                data?['defaultVehicleId'] as String?,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedVehicleCard(String? defaultId) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Vehicle>>(
      stream: homeVehicles,
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? const <Vehicle>[];
        Vehicle? vehicle;
        for (final item in vehicles) {
          if (item.id == defaultId) vehicle = item;
        }
        vehicle ??= vehicles.isEmpty ? null : vehicles.first;
        final selected = vehicle;
        final loading = signedIn && !snapshot.hasError && !snapshot.hasData;
        return _HomeSurface(
          onTap: () => push(context, const VehiclesScreen()),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: selected == null
                    ? Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      )
                    : VehiclePhotoPreview(
                        model: selected.label,
                        photoData: selected.photoData,
                        height: 80,
                        compact: true,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? (loading
                                ? 'Loading your vehicle…'
                                : snapshot.hasError
                                ? 'Vehicles unavailable'
                                : 'Add your vehicle')
                          : '${selected.make} ${selected.model}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      selected == null
                          ? 'Manage saved vehicles'
                          : '${selected.year} · ${selected.fuelType}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selected.registration,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationButton(BuildContext context, Timestamp? seenAt) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.where((doc) {
              final updatedAt = doc.data()['updatedAt'] as Timestamp?;
              return doc.data()['status'] != 'searching' &&
                  (seenAt == null || (updatedAt?.compareTo(seenAt) ?? 1) > 0);
            }).length ??
            0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              minimumSize: const Size(44, 44),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              if (signedIn) {
                push(context, const DriverNotificationsScreen());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to view request notifications.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_none),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final theme = Theme.of(context);
    return _HomeSurface(
      onTap: updatingLocation ? null : changeHomeLocation,
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your location', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  locationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (updatingLocation)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.edit_location_alt_outlined,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildSosCard(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/images/roadassist_home_scene.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, error, stack) =>
                    const ColoredBox(color: raNavyDeep),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF005780),
                    const Color(0xFF005780).withValues(alpha: .85),
                    Colors.transparent,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'STUCK ON THE ROAD?',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Need roadside help?',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: .8,
                  child: Text(
                    'Get assistance from nearby service providers.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => push(context, const AssistanceTypeScreen()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: raBlue,
                  ),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Request Assistance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHelp(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final items = [
      (
        'Won’t Start',
        'Battery issues',
        Icons.battery_charging_full,
        const Color(0xFFFFEDF0),
        const Color(0xFFC82D46),
        'Battery Jumpstart',
      ),
      (
        'Flat Tyre',
        'Tyre help',
        Icons.tire_repair,
        const Color(0xFFFFF5DC),
        const Color(0xFF8A651C),
        'Flat Tyre',
      ),
      (
        'Towing',
        'Need a tow?',
        Icons.fire_truck_outlined,
        const Color(0xFFE5F1FF),
        raBlue,
        'Vehicle Towing',
      ),
      (
        'Not Sure',
        'Help me decide',
        Icons.help_outline,
        const Color(0xFFE0F7EF),
        const Color(0xFF007D70),
        'General Mechanic',
      ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width:
                    bounds.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 16
                    ? (bounds.maxWidth - 30) / 4
                    : (bounds.maxWidth - 10) / 2,
                child: Material(
                  color: dark
                      ? Color.alphaBlend(
                          item.$5.withValues(alpha: .18),
                          colors.surface,
                        )
                      : item.$4,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => push(
                      context,
                      BreakdownDetailsScreen(issues: [item.$6]),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            item.$3,
                            size: 36,
                            color: dark ? colors.primary : item.$5,
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.textScalerOf(context).scale(14) *
                                  2.6,
                            ),
                            child: Text(
                              item.$1,
                              style: Theme.of(context).textTheme.labelLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.textScalerOf(context).scale(14) *
                                  3,
                            ),
                            child: Text(
                              item.$2,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        final requestCount = snapshot.data?.docs.length;
        return Row(
          children: [
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.person_search_outlined,
                label: 'Providers',
                // TODO: pass the real online-provider count here
                count: null,
                onTap: () => push(context, const ProviderDirectoryScreen()),
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Requests',
                count: requestCount,
                onTap: () => push(context, const HistoryScreen()),
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.support_agent_outlined,
                label: 'Support',
                // TODO: pass open support ticket count here
                count: null,
                onTap: () =>
                    push(context, const SupportScreen(isProvider: false)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveAssistance(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) {
    final data = request.data();
    final status = data['status'] as String? ?? 'searching';
    final provider = data['providerName'] as String? ?? 'Finding a provider';
    final phone = data['providerPhone'] as String? ?? '';
    final assigned = (data['providerId'] as String? ?? '').isNotEmpty;
    final theme = Theme.of(context);
    final label = switch (status) {
      'searching' => 'Finding providers',
      'accepted' => 'Request accepted',
      'en_route' => 'Provider is on the way',
      'arrived' => 'Provider has arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'View request',
    };
    final draft = requestDraftFromData(data);
    void openRequest() {
      if (status == 'searching') {
        push(context, SearchingScreen(draft: draft, requestId: request.id));
      } else if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
        push(context, TrackingScreen(draft: draft, requestId: request.id));
      } else {
        push(
          context,
          RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
        );
      }
    }

    return _HomeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ROADSIDE ASSISTANCE',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconBadge(
                Icons.build_rounded,
                size: 52,
                color: theme.colorScheme.primary,
                background: theme.colorScheme.primaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      requestIssueLabel(data),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: label,
              tone: status == 'cancelled'
                  ? RaTone.danger
                  : status == 'searching'
                  ? RaTone.info
                  : RaTone.success,
            ),
          ),
          if (const [
            'accepted',
            'en_route',
            'arrived',
            'completed',
          ].contains(status)) ...[
            const SizedBox(height: 20),
            StatusTimeline(
              statuses: const [
                'Accepted',
                'On the way',
                'On site',
                'Completed',
              ],
              current: const [
                'accepted',
                'en_route',
                'arrived',
                'completed',
              ].indexOf(status),
            ),
          ],
          const SizedBox(height: 16),
          if (assigned)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => push(
                    context,
                    ChatScreen(
                      requestId: request.id,
                      peerName: provider,
                      peerPhone: phone,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                ),
                OutlinedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => showCallPrompt(
                          context,
                          name: provider,
                          number: phone,
                        ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call Provider'),
                ),
              ],
            ),
          TextButton.icon(
            onPressed: openRequest,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('View assistance'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        if (!signedIn) {
          return _homeContent(
            context,
            const InlineMessage(
              icon: Icons.login_outlined,
              text: 'Sign in to view and track your requests.',
            ),
          );
        }
        if (snapshot.hasError) {
          return _homeContent(
            context,
            const InlineMessage(
              icon: Icons.cloud_off_outlined,
              text: 'Unable to load your requests.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(minHeight: 4),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return _homeContent(
            context,
            const InlineMessage(
              icon: Icons.receipt_long_outlined,
              text: 'No assistance requests yet.',
            ),
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
        return _homeContent(
          context,
          active.isEmpty
              ? _DriverRequestPreview(request: requests.first)
              : _buildActiveAssistance(active.first),
        );
      },
    );
  }

  Widget _buildEmergencyContacts(BuildContext context) {
    return _HomeSurface(
      radius: 22,
      padding: EdgeInsets.zero,
      child: _homeContent(
        context,
        Column(
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
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const ServiceNotice(),
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSosCard(context),
                const SizedBox(height: RaSpace.lg),
                _HomeSectionTitle(
                  'Quick Help',
                  action: 'See all',
                  onAction: () => push(context, const AssistanceTypeScreen()),
                ),
                const SizedBox(height: 12),
                _buildQuickHelp(context),
                const SizedBox(height: RaSpace.xxl),
                _HomeSectionTitle(
                  'Active Assistance',
                  action: 'View all',
                  onAction: () => push(context, const HistoryScreen()),
                ),
                const _ChatInbox(isProvider: false, buttonOnly: true),
                const SizedBox(height: RaSpace.md),
                _buildMyRequests(context),
                const SizedBox(height: 16),
                _buildLocationCard(context),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: RaSpace.xxl),
                _HomeSectionTitle(
                  'Nearby Assistance',
                  action: 'See All',
                  onAction: () =>
                      push(context, const ProviderDirectoryScreen()),
                ),
                const SizedBox(height: RaSpace.md),
                _homeContent(context, const _NearbyProvidersPreview()),
                const SizedBox(height: RaSpace.xxl),
                const _HomeSectionTitle('Emergency Contacts'),
                const SizedBox(height: RaSpace.md),
                _buildEmergencyContacts(context),
                const SizedBox(height: RaSpace.xl),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
