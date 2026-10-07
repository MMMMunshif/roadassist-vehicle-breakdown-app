part of '../../screens.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({
    super.key,
    required this.draft,
  });

  final RequestDraft draft;

  @override
  State<LocationScreen> createState() =>
      _LocationScreenState();
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

    selectedPoint = LatLng(
      draft.latitude,
      draft.longitude,
    );

    landmarkController = TextEditingController(
      text: draft.landmark,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        useCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    landmarkController.dispose();
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission denied.',
        );
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      final point = LatLng(
        position.latitude,
        position.longitude,
      );

      var locationLabel =
          'Current GPS (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';

      try {
        final places =
            await Geocoding()
                .placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        );

        if (places.isNotEmpty) {
          final place = places.first;

          final resolved = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ]
              .whereType<String>()
              .where(
                (part) =>
                    part.trim().isNotEmpty,
              )
              .toSet()
              .join(', ');

          if (resolved.isNotEmpty) {
            locationLabel = resolved;
          }
        }
      } catch (_) {
        // Coordinates remain usable if reverse geocoding fails.
      }

      if (!mounted) return;

      setState(() {
        selectedPoint = point;

        draft = draft.copyWith(
          location: locationLabel,
          latitude: point.latitude,
          longitude: point.longitude,
          locationAccuracyMeters:
              position.accuracy,
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

      final message =
          error is LocationServiceDisabledException
              ? 'Location services are turned off. Enable GPS or choose the location manually.'
              : error is PermissionDeniedException
                  ? 'Location permission was denied. Allow access or choose the location manually.'
                  : 'Unable to get your GPS location. Try again or set the location manually.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              Theme.of(context).colorScheme.error,
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

  Future<void> selectMapPosition(
    LatLng point,
  ) async {
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
      const SnackBar(
        content: Text(
          'Breakdown point updated.',
        ),
      ),
    );
  }

  Future<void> editLocation() async {
    final controller = TextEditingController(
      text: draft.location,
    );

    final result =
        await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            MediaQuery.of(sheetContext)
                    .viewInsets
                    .bottom +
                RaSpace.lg,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: theme
                          .colorScheme
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(16),
                    ),
                    child: Icon(
                      Icons
                          .edit_location_alt_outlined,
                      color: theme
                          .colorScheme
                          .onPrimaryContainer,
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
                          'Enter location manually',
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
                          height: 2,
                        ),
                        Text(
                          'Use a street, building, city or recognizable landmark.',
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 2,
                textCapitalization:
                    TextCapitalization.words,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Address or location',
                  hintText:
                      'Example: Galle Road, Colombo 03',
                  prefixIcon:
                      Icon(
                    Icons.place_outlined,
                  ),
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              FilledButton.icon(
                onPressed: () {
                  final value =
                      controller.text.trim();

                  if (value.isNotEmpty) {
                    Navigator.pop(
                      sheetContext,
                      value,
                    );
                  }
                },
                icon: const Icon(
                  Icons.check_rounded,
                ),
                label: const Text(
                  'Use This Location',
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      draft = draft.copyWith(
        location: result,
        clearLocationAccuracy: true,
      );
    });

    await RequestDraftStore().save(draft);
  }

  void updateLandmark(
    String value,
  ) {
    draft = draft.copyWith(
      landmark: value.trim(),
    );

    RequestDraftStore().save(draft);
  }

  Future<void> continueToProviders() async {
    FocusScope.of(context).unfocus();

    draft = draft.copyWith(
      landmark:
          landmarkController.text.trim(),
    );

    await RequestDraftStore().save(draft);

    if (!mounted) return;

    push(
      context,
      ProvidersScreen(
        draft: draft,
      ),
    );
  }

  Widget _buildProgress(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      children: [
        Row(
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
                color: colors
                    .primaryContainer,
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
                    Icons
                        .location_on_outlined,
                    size: 16,
                    color: colors
                        .onPrimaryContainer,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    'LOCATION',
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: colors
                          .onPrimaryContainer,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          .8,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Next: Providers',
              style: theme
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                color: colors.primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: RaSpace.sm,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .63,
            minHeight: 6,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: MapMock(
              key: ValueKey(
                '${selectedPoint.latitude}-${selectedPoint.longitude}',
              ),
              position: selectedPoint,
              onPositionSelected:
                  selectMapPosition,
            ),
          ),

          Positioned(
            top: RaSpace.md,
            left: RaSpace.md,
            right: RaSpace.md,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: RaSpace.md,
                  vertical: RaSpace.sm,
                ),
                decoration:
                    BoxDecoration(
                  color: colors.surface
                      .withValues(
                    alpha: .94,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: .07,
                      ),
                      blurRadius: 16,
                      offset:
                          const Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .touch_app_outlined,
                      size: 18,
                      color:
                          colors.primary,
                    ),
                    const SizedBox(
                      width: RaSpace.sm,
                    ),
                    const Expanded(
                      child: Text(
                        'Tap the map to move the breakdown pin',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: RaSpace.md,
            bottom: RaSpace.md,
            child: FloatingActionButton.small(
              heroTag:
                  'current_location_button',
              tooltip:
                  'Use current location',
              onPressed: locating
                  ? null
                  : useCurrentLocation,
              child: locating
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .my_location_rounded,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(15),
                ),
                child: Icon(
                  Icons
                      .location_on_rounded,
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
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Breakdown location',
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      draft.location,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          _RaLocationAccuracyCard(
            accuracy:
                draft.locationAccuracyMeters,
            onRefresh: locating
                ? null
                : useCurrentLocation,
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed: locating
                      ? null
                      : useCurrentLocation,
                  icon: locating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .my_location_outlined,
                        ),
                  label: Text(
                    locating
                        ? 'Locating…'
                        : 'Use GPS',
                  ),
                ),
              ),

              const SizedBox(
                width: RaSpace.sm,
              ),

              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      editLocation,
                  icon: const Icon(
                    Icons
                        .edit_location_alt_outlined,
                  ),
                  label: const Text(
                    'Edit',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkCard(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: colors
                      .secondaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(14),
                ),
                child: Icon(
                  Icons
                      .signpost_outlined,
                  color: colors
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
                    Text(
                      'Nearby landmark',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      'Optional, but useful when the exact roadside position is difficult to find.',
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          TextField(
            controller:
                landmarkController,
            maxLength: 120,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText:
                  'Landmark',
              hintText:
                  'Opposite Majestic City, near railway station...',
              prefixIcon:
                  Icon(
                Icons.place_outlined,
              ),
            ),
            onChanged:
                updateLandmark,
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
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title:
            const Text(
          'Confirm Location',
        ),
        actions: [
          IconButton(
            tooltip: 'GPS help',
            onPressed: () => push(
              context,
              const GpsIssueScreen(),
            ),
            icon: const Icon(
              Icons
                  .gps_not_fixed_rounded,
            ),
          ),
          const SizedBox(
            width: RaSpace.sm,
          ),
        ],
      ),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  RaSpace.lg,
                  RaSpace.sm,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  _buildProgress(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  Text(
                    'Where are you?',
                    style: theme
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Confirm the exact breakdown point so providers can find you without unnecessary delays.',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),

                  _buildMap(
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
                        RaSpace.md,
                  ),

                  _buildLandmarkCard(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.lg,
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
                        alpha: .32,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Icon(
                          Icons
                              .privacy_tip_outlined,
                          color: colors
                              .primary,
                          size: 19,
                        ),
                        const SizedBox(
                          width:
                              RaSpace.sm,
                        ),
                        Expanded(
                          child: Text(
                            'Your breakdown location is used to identify suitable nearby providers and assist with navigation.',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _RaLocationBottomBar(
              onContinue:
                  continueToProviders,
            ),
          ],
        ),
      ),
    );
  }
}

class _RaLocationAccuracyCard
    extends StatelessWidget {
  const _RaLocationAccuracyCard({
    required this.accuracy,
    required this.onRefresh,
  });

  final double? accuracy;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final double? value =
        accuracy;

    late final String title;
    late final String subtitle;
    late final IconData icon;
    late final Color color;

    if (value == null) {
      title = 'Manual / pinned location';
      subtitle =
          'GPS accuracy is not available for this pin.';
      icon =
          Icons.gps_not_fixed_rounded;
      color = colors.primary;
    } else if (value <= 8) {
      title = 'High GPS accuracy';
      subtitle =
          'Estimated accuracy ±${value.ceil()} m';
      icon =
          Icons.gps_fixed_rounded;
      color = raSuccess;
    } else if (value <= 35) {
      title = 'Moderate GPS accuracy';
      subtitle =
          'Estimated accuracy ±${value.ceil()} m';
      icon =
          Icons.gps_not_fixed_rounded;
      color = raGold;
    } else {
      title = 'Low GPS accuracy';
      subtitle =
          'Estimated accuracy ±${value.ceil()} m • refresh recommended';
      icon =
          Icons.gps_off_rounded;
      color = colors.error;
    }

    return Material(
      color: color.withValues(
        alpha: .08,
      ),
      borderRadius:
          BorderRadius.circular(15),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(15),
        onTap:
            value == null ||
                    value > 35
                ? onRefresh
                : null,
        child: Padding(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 21,
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
                      title,
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        color: color,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
              if ((value == null ||
                      value > 35) &&
                  onRefresh != null)
                Icon(
                  Icons.refresh_rounded,
                  color: color,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaLocationBottomBar
    extends StatelessWidget {
  const _RaLocationBottomBar({
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        RaSpace.lg,
        RaSpace.sm,
        RaSpace.lg,
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors
                .outlineVariant
                .withValues(alpha: .6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: .04),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(
              Icons
                  .arrow_forward_rounded,
            ),
            label: const Text(
              'Continue to Providers',
            ),
          ),
        ),
      ),
    );
  }
}