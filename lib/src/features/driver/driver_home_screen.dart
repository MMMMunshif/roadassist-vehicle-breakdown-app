part of '../../screens.dart';

// -----------------------------------------------------------------------------
// Driver Home UI
// -----------------------------------------------------------------------------

class _RoadAssistLogo extends StatelessWidget {
  const _RoadAssistLogo({this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.add_road_rounded,
            color: colors.onPrimary,
            size: size * .55,
          ),
          Positioned(
            right: size * .08,
            bottom: size * .08,
            child: Container(
              width: size * .30,
              height: size * .30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: .15),
                ),
              ),
              child: Icon(
                Icons.build_rounded,
                size: size * .17,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    required this.child,
    this.padding = const EdgeInsets.all(RaSpace.lg),
    this.radius = 20,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: color ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: .55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle(
    this.title, {
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!),
          ),
      ],
    );
  }
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _HomeSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: RaSpace.sm,
        vertical: RaSpace.md,
      ),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final background = dark
        ? Color.alphaBlend(
            tone.withValues(alpha: .12),
            colors.surface,
          )
        : tone.withValues(alpha: .08);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: tone.withValues(alpha: dark ? .28 : .14),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: dark ? .18 : .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 24,
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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

class _EmergencyActionCard extends StatelessWidget {
  const _EmergencyActionCard({
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
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: colors.errorContainer.withValues(alpha: .45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colors.error.withValues(alpha: .16),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.md),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: colors.error,
                  size: 25,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

      locationProfileSubscription =
          AuthService().watchCurrentProfile().listen(
        (snapshot) {
          final saved =
              snapshot.data()?['currentLocationLabel'] as String?;

          if (mounted &&
              saved != null &&
              saved.trim().isNotEmpty) {
            setState(() => locationLabel = saved);
          }
        },
      );
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
        'currentLatitude': latitude,
        'currentLongitude': longitude,
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
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';

      try {
        final places =
            await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (places.isNotEmpty) {
          final place = places.first;

          label = [
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
      } catch (_) {}

      await saveLocation(
        label,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location updated.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update location: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => updatingLocation = false);
      }
    }
  }

  Future<void> enterLocationManually() async {
    final controller =
        TextEditingController(text: locationLabel);

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.edit_location_alt_outlined,
        ),
        title: const Text(
          'Change current location',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Street, city or landmark',
            hintText: 'Example: Galle Road, Colombo 03',
          ),
          onSubmitted: (value) {
            Navigator.pop(
              dialogContext,
              value.trim(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                controller.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value != null && value.isNotEmpty) {
      await saveLocation(value);
    }
  }

  Future<void> changeHomeLocation() async {
    final action =
        await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            RaSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update location',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(
                height: RaSpace.md,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(
                  Icons.my_location_outlined,
                ),
                title: const Text(
                  'Use current GPS location',
                ),
                subtitle: const Text(
                  'Use your device location for nearby assistance.',
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                ),
                onTap: () =>
                    Navigator.pop(
                  sheetContext,
                  'gps',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(
                  Icons.edit_location_alt_outlined,
                ),
                title: const Text(
                  'Enter location manually',
                ),
                subtitle: const Text(
                  'Use a street, city or nearby landmark.',
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                ),
                onTap: () =>
                    Navigator.pop(
                  sheetContext,
                  'manual',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'gps') {
      await useCurrentHomeLocation();
    } else if (action == 'manual') {
      await enterLocationManually();
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: signedIn
          ? AuthService().watchCurrentProfile()
          : null,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final name =
            data?['displayName'] as String? ??
                (firebaseReady
                    ? FirebaseAuth
                        .instance
                        .currentUser
                        ?.displayName
                    : null) ??
                'Driver';

        final photo =
            data?['photoData'] as String?;

        Widget avatar = ProfileInitials(
          name: name,
          radius: 22,
        );

        if (photo != null &&
            photo.isNotEmpty) {
          try {
            avatar = ClipOval(
              child: Image.memory(
                base64Decode(photo),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, error, stack) =>
                        ProfileInitials(
                  name: name,
                  radius: 22,
                ),
              ),
            );
          } on FormatException {}
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            RaSpace.lg,
            RaSpace.xl,
            RaSpace.md,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _RoadAssistLogo(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Road',
                            style: TextStyle(
                              color:
                                  colors.onSurface,
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
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                  _buildNotificationButton(
                    context,
                    data?[
                            'notificationsSeenAt']
                        as Timestamp?,
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color:
                        Colors.transparent,
                    shape:
                        const CircleBorder(),
                    clipBehavior:
                        Clip.antiAlias,
                    child: InkWell(
                      onTap: () => push(
                        context,
                        const DriverProfileScreen(),
                      ),
                      child: avatar,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: RaSpace.lg,
              ),
              Text(
                '$greeting,',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your roadside companion, whenever you need help.',
                style:
                    theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationButton(
    BuildContext context,
    Timestamp? seenAt,
  ) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn
          ? RequestService()
              .watchDriverRequests()
          : null,
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.where((doc) {
                  final updatedAt =
                      doc.data()['updatedAt']
                          as Timestamp?;

                  return doc.data()['status'] !=
                          'searching' &&
                      (seenAt == null ||
                          (updatedAt?.compareTo(
                                    seenAt,
                                  ) ??
                                  1) >
                              0);
                }).length ??
                0;

        return Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 9
                ? '9+'
                : '$count',
          ),
          child: IconButton.filledTonal(
            tooltip: 'Notifications',
            onPressed: () {
              if (signedIn) {
                push(
                  context,
                  const DriverNotificationsScreen(),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sign in to view request notifications.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedVehicleCard(
    String? defaultId,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<List<Vehicle>>(
      stream: homeVehicles,
      builder: (context, snapshot) {
        final vehicles =
            snapshot.data ??
                const <Vehicle>[];

        Vehicle? vehicle;

        for (final item in vehicles) {
          if (item.id == defaultId) {
            vehicle = item;
            break;
          }
        }

        vehicle ??= vehicles.isEmpty
            ? null
            : vehicles.first;

        final selected = vehicle;

        final loading =
            signedIn &&
                !snapshot.hasError &&
                !snapshot.hasData;

        return _HomeSurface(
          onTap: () => push(
            context,
            const VehiclesScreen(),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(
                    'YOUR VEHICLE',
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight:
                          FontWeight.w800,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  )),
                  if (selected != null)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .primaryContainer,
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                      child: Text(
                        'Default',
                        style: theme
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                          color: colors
                              .onPrimaryContainer,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(
                height: RaSpace.md,
              ),
              Row(
                children: [
                  Container(
                    width: 88,
                    height: 70,
                    clipBehavior:
                        Clip.antiAlias,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: selected == null
                        ? Icon(
                            Icons
                                .directions_car_outlined,
                            size: 38,
                            color:
                                colors.primary,
                          )
                        : VehiclePhotoPreview(
                            model:
                                selected.label,
                            photoData:
                                selected
                                    .photoData,
                            height: 70,
                            compact: true,
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
                          selected == null
                              ? loading
                                  ? 'Loading your vehicle…'
                                  : snapshot
                                          .hasError
                                      ? 'Vehicles unavailable'
                                      : 'Add your vehicle'
                              : '${selected.make} ${selected.model}',
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
                                    .w800,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          selected == null
                              ? 'Manage saved vehicles'
                              : '${selected.year} • ${selected.fuelType}',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                        if (selected !=
                                null &&
                            selected
                                .registration
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(
                            height: 7,
                          ),
                          Text(
                            selected
                                .registration,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                              color: colors
                                  .primary,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  .4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: RaSpace.sm,
                  ),
                  Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssistanceHero(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness ==
            Brightness.dark;

    final start = dark
        ? const Color(0xFF0C4B84)
        : raBlueDeep;

    final end = dark
        ? const Color(0xFF07685F)
        : const Color(0xFF007D70);

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(24),
      child: Material(
        color: start,
        child: InkWell(
          onTap: () => push(
            context,
            const AssistanceTypeScreen(),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -32,
                top: -28,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color: Colors.white
                        .withValues(
                      alpha: .08,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 14,
                child: Icon(
                  Icons
                      .car_repair_rounded,
                  size: 104,
                  color: Colors.white
                      .withValues(
                    alpha: .10,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  RaSpace.xl,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin: Alignment
                        .topLeft,
                    end: Alignment
                        .bottomRight,
                    colors: [
                      start,
                      end,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
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
                        color:
                            Colors.white
                                .withValues(
                          alpha: .14,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                      child: const Text(
                        'ROADSIDE ASSISTANCE',
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 10.5,
                          fontWeight:
                              FontWeight
                                  .w900,
                          letterSpacing:
                              1.2,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      'Need roadside help?',
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    SizedBox(
                      width: 260,
                      child: Text(
                        'Tell us what happened and connect with nearby service providers.',
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Colors
                              .white
                              .withValues(
                            alpha: .88,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height:
                          RaSpace.xl,
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          push(
                        context,
                        const AssistanceTypeScreen(),
                      ),
                      style:
                          FilledButton
                              .styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            colors.primary,
                        minimumSize:
                            const Size(
                          0,
                          50,
                        ),
                      ),
                      icon: const Icon(
                        Icons
                            .add_road_rounded,
                      ),
                      label: const Text(
                        'Request Assistance',
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

  Widget _buildQuickHelp(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final items = [
      (
        'Won’t Start',
        'Battery help',
        Icons
            .battery_charging_full_rounded,
        'Battery Jumpstart',
        colors.error,
      ),
      (
        'Flat Tyre',
        'Tyre assistance',
        Icons.tire_repair_rounded,
        'Flat Tyre',
        const Color(0xFFC17A00),
      ),
      (
        'Towing',
        'Recovery service',
        Icons.fire_truck_outlined,
        'Vehicle Towing',
        colors.primary,
      ),
      (
        'Not Sure',
        'Help me decide',
        Icons.help_outline_rounded,
        'General Mechanic',
        colors.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        const gap = RaSpace.sm;

        final width =
            (constraints.maxWidth -
                    gap) /
                2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child:
                    _QuickHelpCard(
                  title: item.$1,
                  subtitle: item.$2,
                  icon: item.$3,
                  tone: item.$5,
                  onTap: () => push(
                    context,
                    BreakdownDetailsScreen(
                      issues: [
                        item.$4,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActiveAssistance(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        request,
  ) {
    final data = request.data();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status =
        data['status'] as String? ??
            'searching';

    final provider =
        data['providerName']
                as String? ??
            'Finding a provider';

    final phone =
        data['providerPhone']
                as String? ??
            '';

    final assigned =
        (data['providerId']
                    as String? ??
                '')
            .isNotEmpty;

    final label = switch (status) {
      'searching' =>
        'Finding providers',
      'accepted' =>
        'Request accepted',
      'en_route' =>
        'Provider is on the way',
      'arrived' =>
        'Provider has arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'View request',
    };

    final tone =
        status == 'cancelled'
            ? RaTone.danger
            : status == 'searching'
                ? RaTone.info
                : RaTone.success;

    final draft =
        requestDraftFromData(data);

    void openRequest() {
      if (status == 'searching') {
        push(
          context,
          SearchingScreen(
            draft: draft,
            requestId: request.id,
          ),
        );
      } else if (const [
        'accepted',
        'en_route',
        'arrived',
      ].contains(status)) {
        push(
          context,
          TrackingScreen(
            draft: draft,
            requestId: request.id,
          ),
        );
      } else {
        push(
          context,
          RealtimeDriverRequestDetailsScreen(
            requestId: request.id,
            data: data,
          ),
        );
      }
    }

    final timelineIndex = const [
      'accepted',
      'en_route',
      'arrived',
      'completed',
    ].indexOf(status);

    return _HomeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(
              RaSpace.lg,
              RaSpace.lg,
              RaSpace.lg,
              RaSpace.md,
            ),
            decoration: BoxDecoration(
              color: status == 'searching'
                  ? colors.primaryContainer
                      .withValues(
                      alpha: .35,
                    )
                  : colors.surface,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration:
                      BoxDecoration(
                    color:
                        status ==
                                'searching'
                            ? colors
                                .primaryContainer
                            : colors
                                .secondaryContainer,
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),
                  child: Icon(
                    status ==
                            'searching'
                        ? Icons
                            .person_search_rounded
                        : Icons
                            .build_circle_outlined,
                    color:
                        status ==
                                'searching'
                            ? colors
                                .onPrimaryContainer
                            : colors
                                .onSecondaryContainer,
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
                      StatusPill(
                        label: label,
                        tone: tone,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        provider,
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
                        height: 3,
                      ),
                      Text(
                        requestIssueLabel(
                          data,
                        ),
                        maxLines: 2,
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
              ],
            ),
          ),

          if (timelineIndex >= 0) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                RaSpace.lg,
                RaSpace.lg,
                RaSpace.lg,
                RaSpace.md,
              ),
              child: StatusTimeline(
                statuses: const [
                  'Accepted',
                  'On way',
                  'Arrived',
                  'Completed',
                ],
                current:
                    timelineIndex,
              ),
            ),
          ],

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              RaSpace.lg,
              RaSpace.sm,
              RaSpace.lg,
              RaSpace.lg,
            ),
            child: Column(
              children: [
                if (assigned) ...[
                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton
                                .icon(
                          onPressed:
                              () => push(
                            context,
                            ChatScreen(
                              requestId:
                                  request
                                      .id,
                              peerName:
                                  provider,
                              peerPhone:
                                  phone,
                            ),
                          ),
                          icon:
                              const Icon(
                            Icons
                                .chat_bubble_outline_rounded,
                          ),
                          label:
                              const Text(
                            'Message',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width:
                            RaSpace.sm,
                      ),
                      Expanded(
                        child:
                            OutlinedButton
                                .icon(
                          onPressed:
                              phone.isEmpty
                                  ? null
                                  : () =>
                                      showCallPrompt(
                                        context,
                                        name:
                                            provider,
                                        number:
                                            phone,
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
                    ],
                  ),
                  const SizedBox(
                    height: RaSpace.sm,
                  ),
                ],
                SizedBox(
                  width:
                      double.infinity,
                  child: FilledButton
                      .tonalIcon(
                    onPressed:
                        openRequest,
                    icon: Icon(
                      status ==
                              'searching'
                          ? Icons
                              .search_rounded
                          : Icons
                              .navigation_outlined,
                    ),
                    label: Text(
                      status ==
                              'searching'
                          ? 'View Provider Search'
                          : 'View Assistance',
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

  Widget _buildNoActiveAssistance(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return _HomeSurface(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              Icons.route_outlined,
              color:
                  colors.onSurfaceVariant,
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
                  'No active assistance',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Need help? Start a roadside request anytime.',
                  style:
                      theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                'Request assistance',
            onPressed: () => push(
              context,
              const AssistanceTypeScreen(),
            ),
            icon: const Icon(
              Icons.arrow_forward_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests(
    BuildContext context,
  ) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: signedIn
          ? RequestService()
              .watchDriverRequests()
          : null,
      builder: (context, snapshot) {
        if (!signedIn) {
          return const InlineMessage(
            icon:
                Icons.login_outlined,
            text:
                'Sign in to view and track your requests.',
          );
        }

        if (snapshot.hasError) {
          return const InlineMessage(
            icon:
                Icons.cloud_off_outlined,
            text:
                'Unable to load your active assistance.',
          );
        }

        if (!snapshot.hasData) {
          return const _HomeSurface(
            child:
                LinearProgressIndicator(
              minHeight: 3,
            ),
          );
        }

        final active =
            snapshot.data!.docs
                .where(
          (request) {
            return const [
              'searching',
              'accepted',
              'en_route',
              'arrived',
            ].contains(
              request
                  .data()['status'],
            );
          },
        ).toList();

        if (active.isEmpty) {
          return _buildNoActiveAssistance(
            context,
          );
        }

        return _buildActiveAssistance(
          active.first,
        );
      },
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return _HomeSurface(
      onTap: updatingLocation
          ? null
          : changeHomeLocation,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color:
                  colors.primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                14,
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
                  'Current location',
                  style: theme
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  locationLabel,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(
            width: RaSpace.sm,
          ),
          if (updatingLocation)
            const SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          else
            Tooltip(
              message: 'Change location',
              child: Icon(Icons.edit_location_alt_outlined, color: colors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _HomeQuickAction(
            icon: Icons.person_search_outlined,
            label: 'Providers',
            onTap: () => push(
              context,
              const ProviderDirectoryScreen(),
            ),
          ),
        ),
        const SizedBox(
          width: RaSpace.sm,
        ),
        Expanded(
          child: _HomeQuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'Requests',
            onTap: () => push(
              context,
              const HistoryScreen(),
            ),
          ),
        ),
        const SizedBox(
          width: RaSpace.sm,
        ),
        Expanded(
          child: _HomeQuickAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            onTap: () => push(
              context,
              _ChatInboxScreen(
                isProvider: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContacts(
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _EmergencyActionCard(
              title: 'Police',
              number: '119',
              icon: Icons.local_police_outlined,
              onTap: () => showCallPrompt(
                context,
                name: 'Police Emergency',
                number: '119',
              ),
            ),
            const SizedBox(
              width: RaSpace.sm,
            ),
            _EmergencyActionCard(
              title: 'Ambulance',
              number: '1990',
              icon: Icons.emergency_outlined,
              onTap: () => showCallPrompt(
                context,
                name: 'Suwa Seriya Ambulance',
                number: '1990',
              ),
            ),
          ],
        ),
        const SizedBox(
          height: RaSpace.sm,
        ),
        const _HomeSurface(
          padding: EdgeInsets.zero,
          child: _DriverEmergencyContactTile(),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return ColoredBox(
      color: Theme.of(context)
          .scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ServiceNotice(),

            _buildHeader(context),

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                RaSpace.lg,
                0,
                RaSpace.lg,
                RaSpace.xxxl,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  StreamBuilder<
                      DocumentSnapshot<
                          Map<String,
                              dynamic>>>(
                    stream: signedIn
                        ? AuthService()
                            .watchCurrentProfile()
                        : null,
                    builder:
                        (
                      context,
                      snapshot,
                    ) =>
                            _buildSavedVehicleCard(
                      snapshot.data
                              ?.data()?[
                          'defaultVehicleId']
                          as String?,
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  _buildAssistanceHero(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  _HomeSectionTitle(
                    'Quick Help',
                    action: 'See all',
                    onAction: () =>
                        push(
                      context,
                      const AssistanceTypeScreen(),
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),

                  _buildQuickHelp(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  _HomeSectionTitle(
                    'Active Assistance',
                    action: 'View all',
                    onAction: () =>
                        push(
                      context,
                      const HistoryScreen(),
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),

                  _buildMyRequests(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  _buildLocationCard(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  _buildQuickActions(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  _HomeSectionTitle(
                    'Nearby Assistance',
                    action: 'See all',
                    onAction: () =>
                        push(
                      context,
                      const ProviderDirectoryScreen(),
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),

                  const _NearbyProvidersPreview(),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _HomeSectionTitle(
                    'Emergency',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),

                  _buildEmergencyContacts(
                    context,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}