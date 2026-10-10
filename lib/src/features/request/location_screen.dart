part of '../../screens.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, required this.draft});

  final RequestDraft draft;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late RequestDraft draft;

  late LatLng selectedPoint;

  late final TextEditingController landmarkController;

  bool locating = false;

  bool hasConfirmedPosition = false;

  @override
  void initState() {
    super.initState();

    draft = widget.draft;

    selectedPoint = LatLng(draft.latitude, draft.longitude);

    landmarkController = TextEditingController(text: draft.landmark);

    hasConfirmedPosition = !draft.location.startsWith('Select current GPS');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !hasConfirmedPosition) {
        unawaited(useCurrentLocation());
      }
    });
  }

  @override
  void dispose() {
    landmarkController.dispose();

    super.dispose();
  }

  Future<String> resolveLocationLabel(LatLng point) async {
    try {
      final places = await Geocoding().placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (places.isNotEmpty) {
        final place = places.first;

        final parts =
            [
                  place.street,
                  place.subLocality,
                  place.locality,
                  place.administrativeArea,
                  place.country,
                ]
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList();

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Coordinates are still valid when reverse geocoding fails.
    }

    return 'GPS location (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);

      final label = await resolveLocationLabel(point);

      if (!mounted) return;

      setState(() {
        selectedPoint = point;

        hasConfirmedPosition = true;

        draft = draft.copyWith(
          location: label,
          latitude: point.latitude,
          longitude: point.longitude,
          locationAccuracyMeters: position.accuracy,
        );
      });

      await RequestDraftStore().save(draft);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated • accuracy ±${position.accuracy.ceil()} m',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is LocationServiceDisabledException
          ? 'Location services are turned off. Enable GPS or enter the location manually.'
          : error is PermissionDeniedException
          ? 'Location permission was denied. Allow access or enter the location manually.'
          : 'Unable to get your GPS location. Try again or set the location manually.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          locating = false;
        });
      }
    }
  }

  Future<void> selectMapPosition(LatLng point) async {
    final label = await resolveLocationLabel(point);

    if (!mounted) return;

    setState(() {
      selectedPoint = point;

      hasConfirmedPosition = true;

      draft = draft.copyWith(
        location: label,
        latitude: point.latitude,
        longitude: point.longitude,
        clearLocationAccuracy: true,
      );
    });

    await RequestDraftStore().save(draft);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Breakdown point updated.')));
  }

  Future<void> editLocation() async {
    final controller = TextEditingController(
      text: hasConfirmedPosition ? draft.location : '',
    );

    final result = await showModalBottomSheet<String>(
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0D2237) : colors.surface,
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
                      color: colors.onSurfaceVariant.withValues(alpha: .24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                const SizedBox(height: 21),

                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.edit_location_alt_outlined,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter location manually',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            'Use a street, building or recognizable landmark.',
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

                const SizedBox(height: 18),

                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Address or location',
                    hintText: 'Example: Galle Road, Colombo 03',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  onSubmitted: (value) {
                    final text = value.trim();

                    if (text.isNotEmpty) {
                      Navigator.pop(sheetContext, text);
                    }
                  },
                ),

                const SizedBox(height: 17),

                FilledButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();

                    if (text.isEmpty) {
                      return;
                    }

                    Navigator.pop(sheetContext, text);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use This Location'),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (result == null || !mounted) {
      return;
    }

    try {
      final locations = await Geocoding().locationFromAddress(result);

      if (locations.isEmpty) {
        throw StateError('Location unavailable');
      }

      final resolved = locations.first;

      final point = LatLng(resolved.latitude, resolved.longitude);

      setState(() {
        selectedPoint = point;

        hasConfirmedPosition = true;

        draft = draft.copyWith(
          location: result,
          latitude: resolved.latitude,
          longitude: resolved.longitude,
          clearLocationAccuracy: true,
        );
      });

      await RequestDraftStore().save(draft);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'RoadAssist could not locate that address on the map. Try a more specific street, building or area.',
          ),
        ),
      );
    }
  }

  void updateLandmark(String value) {
    draft = draft.copyWith(landmark: value.trim());

    unawaited(RequestDraftStore().save(draft));
  }

  Future<void> continueToProviders() async {
    FocusScope.of(context).unfocus();

    if (!hasConfirmedPosition) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm your breakdown location before continuing.'),
        ),
      );

      return;
    }

    draft = draft.copyWith(landmark: landmarkController.text.trim());

    await RequestDraftStore().save(draft);

    if (!mounted) return;

    push(context, ProvidersScreen(draft: draft));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Breakdown Location',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const _RaLocationProgress(),

                  const SizedBox(height: 16),

                  const _RaLocationHero(),

                  const SizedBox(height: 18),

                  _RaLocationCurrentCard(
                    location: hasConfirmedPosition
                        ? draft.location
                        : 'Location not confirmed',
                    accuracy: draft.locationAccuracyMeters,
                    locating: locating,
                    confirmed: hasConfirmedPosition,
                    onGps: useCurrentLocation,
                    onEdit: editLocation,
                  ),

                  const SizedBox(height: 15),

                  if (hasConfirmedPosition)
                    _RaLocationMapCard(
                      point: selectedPoint,
                      onTap: selectMapPosition,
                    )
                  else
                    const _RaLocationWaitingMap(),

                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF0D2237)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 41,
                              height: 41,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.signpost_outlined,
                                color: colors.primary,
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 11),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nearby landmark',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Optional, but useful when the exact roadside point is difficult to find.',
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

                        const SizedBox(height: 14),

                        TextField(
                          controller: landmarkController,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Landmark or access note',
                            hintText: 'Near fuel station, opposite school...',
                            prefixIcon: Icon(
                              Icons.assistant_direction_outlined,
                            ),
                          ),
                          onChanged: updateLandmark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.my_location_outlined,
                          color: colors.primary,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Tap the map to fine-tune the exact breakdown point. Providers use this location for distance and navigation.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: hasConfirmedPosition ? continueToProviders : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    hasConfirmedPosition
                        ? 'Continue to Providers'
                        : 'Confirm Location First',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaLocationProgress extends StatelessWidget {
  const _RaLocationProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'STEP 3 OF 4',
                style: GoogleFonts.plusJakartaSans(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Location',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .75,
            minHeight: 5,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaLocationHero extends StatelessWidget {
  const _RaLocationHero();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B477D), Color(0xFF08645D)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -31,
            child: Icon(
              Icons.location_on_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: .06),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'Where are you?',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.55,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: 295,
                child: Text(
                  'Confirm the exact breakdown point so RoadAssist can find suitable providers and guide them to you.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaLocationCurrentCard extends StatelessWidget {
  const _RaLocationCurrentCard({
    required this.location,
    required this.accuracy,
    required this.locating,
    required this.confirmed,
    required this.onGps,
    required this.onEdit,
  });

  final String location;

  final double? accuracy;

  final bool locating;
  final bool confirmed;

  final VoidCallback onGps;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: confirmed
              ? colors.primary.withValues(alpha: .20)
              : colors.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: confirmed
                      ? colors.primary.withValues(alpha: .09)
                      : raGold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  confirmed
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  color: confirmed ? colors.primary : raGold,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmed ? 'Breakdown point' : 'Location required',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      location,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    if (accuracy != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'GPS accuracy ±${accuracy!.ceil()} m',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: accuracy! <= 50 ? raSuccess : raGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: locating ? null : onGps,
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(locating ? 'Locating…' : 'Use GPS'),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: locating ? null : onEdit,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Enter Address'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaLocationMapCard extends StatelessWidget {
  const _RaLocationMapCard({required this.point, required this.onTap});

  final LatLng point;

  final ValueChanged<LatLng> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .48)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              onTap: (tapPosition, tappedPoint) {
                onTap(tappedPoint);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'road_assist',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 54,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: .25),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car_filled_outlined,
                        color: colors.onPrimary,
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Tap map to adjust pin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaLocationWaitingMap extends StatelessWidget {
  const _RaLocationWaitingMap();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      height: 215,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: colors.primary,
                  size: 27,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Map appears after location confirmation',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Use GPS or enter a specific address first. RoadAssist will not assume a pickup point.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.45,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
