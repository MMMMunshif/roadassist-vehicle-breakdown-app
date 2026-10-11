part of '../../screens.dart';

// =============================================================================
// DRIVER HOME
// =============================================================================

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String locationLabel = 'Location not set';

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

        if (!mounted || saved == null || saved.trim().isEmpty) {
          return;
        }

        setState(() {
          locationLabel = saved;
        });
      });
    }
  }

  @override
  void dispose() {
    locationProfileSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // LOCATION
  // ===========================================================================

  Future<void> saveLocation(
    String label, {
    double? latitude,
    double? longitude,
  }) async {
    setState(() {
      locationLabel = label;
    });

    if (!signedIn) {
      return;
    }

    await AuthService().updateCurrentProfile({
      'currentLocationLabel': label,
      'currentLatitude': latitude,
      'currentLongitude': longitude,
    });
  }

  Future<void> useCurrentHomeLocation() async {
    if (updatingLocation) return;

    setState(() {
      updatingLocation = true;
    });

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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      var label =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';

      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (places.isNotEmpty) {
          final place = places.first;

          final resolved =
              [
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                    place.country,
                  ]
                  .whereType<String>()
                  .where((item) => item.trim().isNotEmpty)
                  .toSet()
                  .join(', ');

          if (resolved.isNotEmpty) {
            label = resolved;
          }
        }
      } catch (_) {
        // Coordinates remain usable when reverse geocoding fails.
      }

      await saveLocation(
        label,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location updated.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is LocationServiceDisabledException
          ? 'Location services are turned off. Enable GPS and try again.'
          : error is PermissionDeniedException
          ? 'Location permission was denied. You can enter your location manually.'
          : 'Unable to update your location. Try again or enter it manually.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingLocation = false;
        });
      }
    }
  }

  Future<void> enterLocationManually() async {
    final controller = TextEditingController(
      text: locationLabel == 'Location not set' ? '' : locationLabel,
    );

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        final dark = theme.brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0C1B29) : colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    _DriverHomeIconBox(
                      icon: Icons.edit_location_alt_rounded,
                      color: colors.primary,
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set your location',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Enter a street, city or nearby landmark.',
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

                const SizedBox(height: 22),

                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Current location',
                    hintText: 'Street, city or landmark',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(sheetContext, value.trim());
                  },
                ),

                const SizedBox(height: 18),

                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext, controller.text.trim());
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Location'),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty || !mounted) {
      return;
    }

    await saveLocation(value.trim());
  }

  Future<void> changeHomeLocation() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        final dark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0C1B29) : colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RoadAssist uses this to show relevant nearby providers.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _DriverHomeSheetAction(
                icon: Icons.my_location_rounded,
                title: 'Use current GPS',
                subtitle: 'Get your current device location automatically.',
                onTap: () {
                  Navigator.pop(sheetContext, 'gps');
                },
              ),

              const SizedBox(height: 10),

              _DriverHomeSheetAction(
                icon: Icons.edit_location_alt_outlined,
                title: 'Enter manually',
                subtitle: 'Use a street, city or nearby landmark.',
                onTap: () {
                  Navigator.pop(sheetContext, 'manual');
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'gps') {
      await useCurrentHomeLocation();
    } else if (action == 'manual') {
      await enterLocationManually();
    }
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(BuildContext context) {
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaProviderHeader(
                notifications: _buildNotificationButton(
                  context,
                  data?['notificationsSeenAt'] as Timestamp?,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '$greeting, $name',
                style: _providerText(context, size: 14, muted: true),
              ),
              const SizedBox(height: 5),
              Text(
                'Wherever you go,\nwe are here.',
                style: _providerText(
                  context,
                  size: 26,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 130,
                    ),
                    child: Text(
                      locationLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: updatingLocation ? null : changeHomeLocation,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationButton(BuildContext context, Timestamp? seenAt) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.where((doc) {
              final data = doc.data();

              final updatedAt = data['updatedAt'] as Timestamp?;

              return data['status'] != 'searching' &&
                  (seenAt == null || (updatedAt?.compareTo(seenAt) ?? 1) > 0);
            }).length ??
            0;

        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              if (!signedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to view request notifications.'),
                  ),
                );

                return;
              }

              push(context, const DriverNotificationsScreen());
            },
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerHighest.withValues(
                alpha: .55,
              ),
              foregroundColor: colors.onSurface,
              minimumSize: const Size(42, 42),
            ),
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // HERO
  // ===========================================================================

  Widget _buildAssistanceHero(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0062DB), Color(0xFF009AF5)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.car_repair_outlined,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need roadside help?',
                    style: _providerText(
                      context,
                      size: 20,
                      weight: FontWeight.w700,
                    ).copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Find nearby assistance and compare provider quotes.',
                    style: _providerText(
                      context,
                      size: 14,
                    ).copyWith(color: Colors.white.withValues(alpha: .88)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0062DB),
          ),
          onPressed: () => push(context, const AssistanceTypeScreen()),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Request Assistance'),
        ),
      ],
    ),
  );

  Widget _buildSavedVehicleCard(String? defaultId) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<List<Vehicle>>(
      stream: homeVehicles,
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? const <Vehicle>[];

        Vehicle? vehicle;

        for (final item in vehicles) {
          if (item.id == defaultId) {
            vehicle = item;
            break;
          }
        }

        vehicle ??= vehicles.isEmpty ? null : vehicles.first;

        final selected = vehicle;

        final loading = signedIn && !snapshot.hasError && !snapshot.hasData;

        return _DriverHomeSurface(
          onTap: () {
            push(context, const VehiclesScreen());
          },
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 70,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: selected == null
                    ? Icon(
                        Icons.directions_car_outlined,
                        size: 36,
                        color: colors.primary,
                      )
                    : VehiclePhotoPreview(
                        model: selected.label,
                        photoData: selected.photoData,
                        height: 70,
                        compact: true,
                      ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'YOUR VEHICLE',
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (selected != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Default',
                              style: GoogleFonts.plusJakartaSans(
                                color: colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      selected == null
                          ? loading
                                ? 'Loading vehicle…'
                                : snapshot.hasError
                                ? 'Vehicles unavailable'
                                : 'Add a vehicle'
                          : '${selected.make} ${selected.model}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      selected == null
                          ? 'Manage saved vehicles'
                          : '${selected.year}  •  ${selected.fuelType}  •  ${selected.transmission}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    if (selected != null &&
                        selected.registration.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        selected.registration,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.primary,
                          fontSize: 13,
                          letterSpacing: .35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 7),

              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // QUICK HELP
  // ===========================================================================

  Widget _buildQuickHelp(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final items = [
      (
        'Won’t Start',
        'Battery assistance',
        Icons.battery_charging_full_rounded,
        'Battery Jumpstart',
        const Color(0xFFDE5147),
      ),
      (
        'Flat Tyre',
        'Tyre assistance',
        Icons.tire_repair_rounded,
        'Flat Tyre',
        const Color(0xFFE49A20),
      ),
      (
        'Towing',
        'Vehicle recovery',
        Icons.fire_truck_outlined,
        'Vehicle Towing',
        colors.primary,
      ),
      (
        'Not Sure',
        'Help identify it',
        Icons.help_outline_rounded,
        'General Mechanic',
        const Color(0xFF178F83),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;

        final singleColumn = constraints.maxWidth < 315;

        final cardWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: _DriverQuickHelpCard(
                  title: item.$1,
                  subtitle: item.$2,
                  icon: item.$3,
                  tone: item.$5,
                  onTap: () {
                    push(context, BreakdownDetailsScreen(issues: [item.$4]));
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ACTIVE ASSISTANCE
  // ===========================================================================

  Widget _buildMyRequests(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        if (!signedIn) {
          return _DriverHomeMessageCard(
            icon: Icons.login_outlined,
            title: 'Sign in to track requests',
            message:
                'Your active roadside assistance will appear here after signing in.',
            action: 'Sign in',
            onTap: null,
          );
        }

        if (snapshot.hasError) {
          return const _DriverHomeMessageCard(
            icon: Icons.cloud_off_outlined,
            title: 'Assistance unavailable',
            message:
                'We could not load your active request. Check your connection.',
          );
        }

        if (!snapshot.hasData) {
          return const _DriverHomeLoadingCard();
        }

        final active = snapshot.data!.docs.where((request) {
          return const [
            'searching',
            'accepted',
            'en_route',
            'arrived',
          ].contains(request.data()['status']);
        }).toList();

        if (active.isEmpty) {
          return _buildNoActiveAssistance(context);
        }

        return _buildActiveAssistance(active.first);
      },
    );
  }

  Widget _buildActiveAssistance(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) {
    final data = request.data();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    final status = data['status'] as String? ?? 'searching';

    final provider = data['providerName'] as String? ?? 'Finding a provider';

    final phone = data['providerPhone'] as String? ?? '';

    final assigned = (data['providerId'] as String? ?? '').trim().isNotEmpty;

    final issue = requestIssueLabel(data);

    final label = switch (status) {
      'searching' => 'Finding providers',
      'accepted' => 'Request accepted',
      'en_route' => 'Provider on the way',
      'arrived' => 'Provider arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Assistance update',
    };

    final tone = switch (status) {
      'cancelled' => RaTone.danger,
      'searching' => RaTone.info,
      _ => RaTone.success,
    };

    final draft = requestDraftFromData(data);

    void openRequest() {
      if (status == 'searching') {
        push(context, SearchingScreen(draft: draft, requestId: request.id));

        return;
      }

      if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
        push(context, TrackingScreen(draft: draft, requestId: request.id));

        return;
      }

      push(
        context,
        RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
      );
    }

    final timelineIndex = const [
      'accepted',
      'en_route',
      'arrived',
      'completed',
    ].indexOf(status);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D2237) : Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: status == 'searching'
              ? colors.primary.withValues(alpha: .22)
              : colors.outlineVariant.withValues(alpha: .48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .13 : .045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: status == 'searching'
                        ? colors.primary.withValues(alpha: .10)
                        : raSuccess.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    status == 'searching'
                        ? Icons.person_search_rounded
                        : status == 'en_route'
                        ? Icons.navigation_rounded
                        : Icons.handyman_outlined,
                    color: status == 'searching' ? colors.primary : raSuccess,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(label: label, tone: tone),

                      const SizedBox(height: 8),

                      Text(
                        provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        issue,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
          ),

          if (timelineIndex >= 0) ...[
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .45),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 12),
              child: StatusTimeline(
                statuses: const ['Accepted', 'On way', 'Arrived', 'Completed'],
                current: timelineIndex,
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(17, 9, 17, 17),
            child: Column(
              children: [
                if (assigned) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            push(
                              context,
                              ChatScreen(
                                requestId: request.id,
                                peerName: provider,
                                peerPhone: phone,
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Message'),
                        ),
                      ),

                      const SizedBox(width: 9),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: phone.trim().isEmpty
                              ? null
                              : () {
                                  showCallPrompt(
                                    context,
                                    name: provider,
                                    number: phone,
                                  );
                                },
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openRequest,
                    icon: Icon(
                      status == 'searching'
                          ? Icons.search_rounded
                          : Icons.near_me_outlined,
                    ),
                    label: Text(
                      status == 'searching'
                          ? 'View Provider Search'
                          : 'Open Live Assistance',
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

  Widget _buildNoActiveAssistance(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _DriverHomeSurface(
      child: Row(
        children: [
          _DriverHomeIconBox(icon: Icons.route_outlined, color: colors.primary),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active assistance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Everything looks clear. Start a request whenever you need roadside help.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Request assistance',
            onPressed: () {
              push(context, const AssistanceTypeScreen());
            },
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOCATION CARD
  // ===========================================================================

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 9.0;

        final width = (constraints.maxWidth - gap * 2) / 3;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              child: _DriverHomeQuickAction(
                icon: Icons.person_search_outlined,
                label: 'Providers',
                onTap: () {
                  push(context, const ProviderDirectoryScreen());
                },
              ),
            ),

            const SizedBox(width: gap),

            SizedBox(
              width: width,
              child: _DriverHomeQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Requests',
                onTap: () {
                  push(context, const HistoryScreen());
                },
              ),
            ),

            const SizedBox(width: gap),

            SizedBox(
              width: width,
              child: _DriverHomeQuickAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                onTap: () {
                  push(context, const _ChatInboxScreen(isProvider: false));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // EMERGENCY
  // ===========================================================================

  Widget _buildEmergencyContacts(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DriverEmergencyActionCard(
                title: 'Police',
                number: '119',
                icon: Icons.local_police_outlined,
                onTap: () {
                  showCallPrompt(
                    context,
                    name: 'Police Emergency',
                    number: '119',
                  );
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _DriverEmergencyActionCard(
                title: 'Ambulance',
                number: '1990',
                icon: Icons.emergency_outlined,
                onTap: () {
                  showCallPrompt(
                    context,
                    name: 'Suwa Seriya Ambulance',
                    number: '1990',
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        const _DriverHomeSurface(
          padding: EdgeInsets.zero,
          child: _DriverEmergencyContactTile(),
        ),
      ],
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) => RaDriverScaffold(
    body: SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
        children: [
          const ServiceNotice(),
          _buildHeader(context),
          _buildAssistanceHero(context),
          const SizedBox(height: 14),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: signedIn ? AuthService().watchCurrentProfile() : null,
            builder: (context, snapshot) => _buildSavedVehicleCard(
              snapshot.data?.data()?['defaultVehicleId'] as String?,
            ),
          ),
          const SizedBox(height: 24),
          _DriverHomeSectionHeader(
            title: 'Active assistance',
            subtitle: 'Follow your current roadside request',
            action: 'Requests',
            onAction: () => push(context, const HistoryScreen()),
          ),
          const SizedBox(height: 10),
          _buildMyRequests(context),
          const SizedBox(height: 24),
          _DriverHomeSectionHeader(
            title: 'Nearby assistance',
            subtitle: 'Online providers within your service area',
            action: 'See all',
            onAction: () => push(context, const ProviderDirectoryScreen()),
          ),
          const SizedBox(height: 10),
          const _NearbyProvidersPreview(),
          const SizedBox(height: 24),
          _DriverHomeSectionHeader(
            title: 'Quick Help',
            subtitle: 'Start with the issue you are facing',
            action: 'View all',
            onAction: () => push(context, const AssistanceTypeScreen()),
          ),
          const SizedBox(height: 10),
          _buildQuickHelp(context),
          const SizedBox(height: 14),
          _buildQuickActions(context),
          const SizedBox(height: 24),
          const _DriverHomeSectionHeader(
            title: 'Emergency',
            subtitle: 'Important contacts when you need urgent help',
          ),
          const SizedBox(height: 10),
          _buildEmergencyContacts(context),
        ],
      ),
    ),
  );
}

// =============================================================================
// SURFACE
// =============================================================================

class _DriverHomeSurface extends StatelessWidget {
  const _DriverHomeSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: dark ? const Color(0xFF0D2237) : Colors.white,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .07)
                  : const Color(0xFFDEE9F2),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _DriverHomeSectionHeader extends StatelessWidget {
  const _DriverHomeSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  letterSpacing: -.35,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),

              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (action != null) ...[
          const SizedBox(width: 8),

          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              action!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// QUICK HELP CARD
// =============================================================================

class _DriverQuickHelpCard extends StatelessWidget {
  const _DriverQuickHelpCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: dark
          ? Color.alphaBlend(
              tone.withValues(alpha: .075),
              const Color(0xFF0D2237),
            )
          : Colors.white,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: dark
                  ? tone.withValues(alpha: .15)
                  : const Color(0xFFDEE9F2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: dark ? .14 : .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: tone, size: 21),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK ACTION
// =============================================================================

class _DriverHomeQuickAction extends StatelessWidget {
  const _DriverHomeQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: dark ? const Color(0xFF0D2237) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 91),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .07)
                  : const Color(0xFFDEE9F2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),

              const SizedBox(height: 8),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
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

// =============================================================================
// ICON BOX
// =============================================================================

class _DriverHomeIconBox extends StatelessWidget {
  const _DriverHomeIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

// =============================================================================
// LOCATION SHEET ITEM
// =============================================================================

class _DriverHomeSheetAction extends StatelessWidget {
  const _DriverHomeSheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .36),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _DriverHomeIconBox(icon: icon, color: colors.primary),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMERGENCY CARD
// =============================================================================

class _DriverEmergencyActionCard extends StatelessWidget {
  const _DriverEmergencyActionCard({
    required this.title,
    required this.number,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String number;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: dark
          ? Color.alphaBlend(
              raDanger.withValues(alpha: .075),
              const Color(0xFF0D2237),
            )
          : Colors.white,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: raDanger.withValues(alpha: dark ? .19 : .13),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: raDanger.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: raDanger, size: 21),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      number,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: raDanger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MESSAGE / EMPTY CARD
// =============================================================================

class _DriverHomeMessageCard extends StatelessWidget {
  const _DriverHomeMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _DriverHomeSurface(
      child: Row(
        children: [
          _DriverHomeIconBox(icon: icon, color: colors.primary),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (action != null && onTap != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onTap, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// LOADING CARD
// =============================================================================

class _DriverHomeLoadingCard extends StatelessWidget {
  const _DriverHomeLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _DriverHomeSurface(
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 8,
                  width: 185,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: .65,
                    ),
                    borderRadius: BorderRadius.circular(999),
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
