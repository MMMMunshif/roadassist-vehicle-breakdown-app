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

  @override
  void initState() {
    super.initState();
    draft = widget.draft;
    selectedPoint = LatLng(draft.latitude, draft.longitude);
    landmarkController = TextEditingController(text: draft.landmark);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) useCurrentLocation();
    });
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);
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
      var locationLabel =
          'Current GPS (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          point.latitude,
          point.longitude,
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
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
          if (resolved.isNotEmpty) locationLabel = resolved;
        }
      } catch (_) {
        // Accurate coordinates remain available when reverse geocoding fails.
      }
      if (!mounted) return;
      setState(() {
        selectedPoint = point;
        draft = draft.copyWith(
          location: locationLabel,
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
            'GPS updated · accuracy ${position.accuracy.toStringAsFixed(0)} m',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is LocationServiceDisabledException
          ? 'Location services are turned off. Enable GPS or set the pin manually.'
          : error is PermissionDeniedException
          ? 'Location permission was denied. Allow it or set the pin manually.'
          : 'Unable to get GPS location. Please try again or set it manually.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> selectMapPosition(LatLng point) async {
    setState(() {
      selectedPoint = point;
      draft = draft.copyWith(
        location:
            'Pinned location (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
        latitude: point.latitude,
        longitude: point.longitude,
        clearLocationAccuracy: true,
      );
    });
    await RequestDraftStore().save(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Breakdown pin moved on the map.')),
    );
  }

  Future<void> editLocation() async {
    var value = draft.location;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit breakdown location'),
        content: TextFormField(
          initialValue: draft.location,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Address or landmark',
            hintText: 'Enter your current location',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final location = value.trim();
              if (location.isNotEmpty) Navigator.pop(dialogContext, location);
            },
            child: const Text('Save Location'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => draft = draft.copyWith(location: result));
      await RequestDraftStore().save(draft);
    }
  }

  void updateLandmark(String value) {
    draft = draft.copyWith(landmark: value.trim());
    RequestDraftStore().save(draft);
  }

  @override
  void dispose() {
    landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Location Confirmation'),
      actions: [
        IconButton(
          onPressed: () => push(context, const GpsIssueScreen()),
          tooltip: 'Test GPS issue state',
          icon: const Icon(Icons.gps_off_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapMock(
                    key: ValueKey(selectedPoint),
                    position: selectedPoint,
                    onPositionSelected: selectMapPosition,
                  ),
                ),
                Positioned(
                  left: RaSpace.lg,
                  right: RaSpace.lg,
                  bottom: RaSpace.lg,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BREAKDOWN POINT', style: RaText.eyebrow),
                          const SizedBox(height: RaSpace.xs),
                          Text(draft.location, style: RaText.headline),
                          const SizedBox(height: RaSpace.xs),
                          StatusPill(
                            label: draft.location.startsWith('Current GPS')
                                ? 'GPS coordinates'
                                : 'Confirmed location',
                            tone: RaTone.warning,
                            dot: false,
                          ),
                          const SizedBox(height: RaSpace.sm),
                          _LocationAccuracyIndicator(
                            accuracyMeters: draft.locationAccuracyMeters,
                            onRefresh: locating ? null : useCurrentLocation,
                          ),
                          const SizedBox(height: RaSpace.md),
                          TextField(
                            controller: landmarkController,
                            maxLength: 120,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nearby Landmark (Optional)',
                              hintText:
                                  'e.g. Opposite Majestic City or near railway station',
                              prefixIcon: Icon(Icons.signpost_outlined),
                            ),
                            onChanged: updateLandmark,
                          ),
                          const SizedBox(height: RaSpace.lg),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: locating
                                      ? null
                                      : useCurrentLocation,
                                  icon: locating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(
                                    locating ? 'Locating...' : 'Current GPS',
                                  ),
                                ),
                              ),
                              const SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: editLocation,
                                  icon: const Icon(Icons.edit_location),
                                  label: const Text('Edit Manually'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Confirm Location',
            onTap: () async {
              await RequestDraftStore().save(draft);
              if (!context.mounted) return;
              push(context, ProvidersScreen(draft: draft));
            },
          ),
        ],
      ),
    ),
  );
}
