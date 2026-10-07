part of '../../screens.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({
    super.key,
    required this.draft,
    this.requestId,
  });

  final RequestDraft draft;
  final String? requestId;

  @override
  State<SearchingScreen> createState() =>
      _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      requestListener;

  Timer? providerResponseTimer;

  late final AnimationController pulseController;

  String requestStatus = 'searching';
  String? requestError;

  bool searchingAllProviders = false;
  bool navigatingToTracking = false;
  bool cancelling = false;

  late String currentLocationLabel;
  late RequestDraft editableDraft;

  bool get activelySearching => requestStatus == 'searching';

  bool get preferredSearch =>
      editableDraft.preferredProviderId.trim().isNotEmpty &&
      !searchingAllProviders;

  @override
  void initState() {
    super.initState();

    currentLocationLabel = widget.draft.location;
    editableDraft = widget.draft;

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.requestId == null) {
      requestStatus = 'not_submitted';
      requestError =
          'This request is not connected to the live assistance system.';
      return;
    }

    requestListener = RequestService()
        .watchRequest(widget.requestId!)
        .listen(
      (snapshot) {
        final data = snapshot.data();

        if (!mounted) return;

        if (data == null) {
          setState(() {
            requestError =
                'This assistance request could not be found.';
          });
          return;
        }

        final status =
            data['status'] as String? ?? 'searching';

        final locationLabel =
            data['locationLabel'] as String? ??
                widget.draft.location;

        final preferredProviderId =
            data['preferredProviderId'] as String? ?? '';

        if (status == 'searching' &&
            preferredProviderId.isNotEmpty) {
          _scheduleProviderTimeout(data);
        } else {
          providerResponseTimer?.cancel();
          providerResponseTimer = null;
        }

        if (const [
              'accepted',
              'en_route',
              'arrived',
              'completed',
            ].contains(status) &&
            !navigatingToTracking) {
          navigatingToTracking = true;

          final latitude =
              (data['latitude'] as num?)?.toDouble();

          final longitude =
              (data['longitude'] as num?)?.toDouble();

          replace(
            context,
            TrackingScreen(
              draft: editableDraft.copyWith(
                location: locationLabel,
                latitude: latitude,
                longitude: longitude,
                landmark:
                    data['landmark'] as String? ??
                        editableDraft.landmark,
                locationAccuracyMeters:
                    (data['locationAccuracyMeters'] as num?)
                        ?.toDouble(),
              ),
              requestId: widget.requestId,
            ),
          );

          return;
        }

        setState(() {
          requestStatus = status;
          currentLocationLabel = locationLabel;

          editableDraft = editableDraft.copyWith(
            description:
                data['description'] as String? ??
                    editableDraft.description,
            notes:
                data['notes'] as String? ??
                    editableDraft.notes,
            location: locationLabel,
            landmark:
                data['landmark'] as String? ??
                    editableDraft.landmark,
            vehiclePhotoUrls:
                (data['vehiclePhotoUrls'] as List<dynamic>? ??
                        const [])
                    .whereType<String>()
                    .toList(),
          );

          requestError = null;

          searchingAllProviders =
              widget.draft.preferredProviderId.isNotEmpty &&
              preferredProviderId.isEmpty;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          requestError =
              'Connection interrupted. RoadAssist will continue when your connection returns.';
        });
      },
    );
  }

  @override
  void dispose() {
    requestListener?.cancel();
    providerResponseTimer?.cancel();
    pulseController.dispose();

    super.dispose();
  }

  void _scheduleProviderTimeout(
    Map<String, dynamic> data,
  ) {
    if (providerResponseTimer != null ||
        widget.requestId == null) {
      return;
    }

    const responseWindow =
        Duration(seconds: 90);

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate();

    final elapsed = createdAt == null
        ? Duration.zero
        : DateTime.now().difference(createdAt);

    final remaining = elapsed >= responseWindow
        ? Duration.zero
        : responseWindow - elapsed;

    providerResponseTimer =
        Timer(remaining, () async {
      providerResponseTimer = null;

      try {
        await RequestService()
            .expandProviderSearch(
          widget.requestId!,
        );
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to expand the provider search yet.',
            ),
          ),
        );
      }
    });
  }

  Future<void> editPendingRequest() async {
    if (widget.requestId == null ||
        requestStatus != 'searching') {
      return;
    }

    final descriptionController =
        TextEditingController(
      text: editableDraft.description,
    );

    final notesController =
        TextEditingController(
      text: editableDraft.notes,
    );

    final locationController =
        TextEditingController(
      text: editableDraft.location,
    );

    final landmarkController =
        TextEditingController(
      text: editableDraft.landmark,
    );

    final photos =
        List<String>.from(
      editableDraft.vehiclePhotoUrls,
    );

    var latitude =
        editableDraft.latitude;

    var longitude =
        editableDraft.longitude;

    var accuracy =
        editableDraft.locationAccuracyMeters;

    var locating = false;
    var preparingPhoto = false;

    final updatedDraft =
        await showModalBottomSheet<RequestDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            final theme =
                Theme.of(context);

            final colors =
                theme.colorScheme;

            Future<void> refreshGps() async {
              setSheetState(() {
                locating = true;
              });

              try {
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
                        LocationPermission
                            .deniedForever) {
                  throw const PermissionDeniedException(
                    'Location permission denied.',
                  );
                }

                final position =
                    await Geolocator
                        .getCurrentPosition(
                  locationSettings:
                      const LocationSettings(
                    accuracy:
                        LocationAccuracy.high,
                  ),
                );

                latitude =
                    position.latitude;
                longitude =
                    position.longitude;
                accuracy =
                    position.accuracy;

                locationController.text =
                    'Current GPS (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
              } catch (_) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(
                    sheetContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to refresh GPS location.',
                      ),
                    ),
                  );
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    locating = false;
                  });
                }
              }
            }

            Future<void> addPhotos() async {
              if (preparingPhoto ||
                  photos.length >= 3) {
                return;
              }

              setSheetState(() {
                preparingPhoto = true;
              });

              try {
                final picked =
                    await ImagePicker()
                        .pickMultiImage(
                  imageQuality: 75,
                  maxWidth: 1600,
                  limit: 3 - photos.length,
                );

                for (final photo in picked) {
                  if (photos.length >= 3) {
                    break;
                  }

                  final encoded =
                      await PhotoUploadService()
                          .prepareVehiclePhoto(
                    photo,
                  );

                  if (!photos.contains(
                    encoded,
                  )) {
                    photos.add(encoded);
                  }
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    preparingPhoto = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                RaSpace.lg,
                0,
                RaSpace.lg,
                MediaQuery.of(context)
                        .viewInsets
                        .bottom +
                    RaSpace.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
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
                            color: colors
                                .primaryContainer,
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
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
                                'Edit pending request',
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
                                'You can update these details until a provider accepts.',
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
                      height: RaSpace.xl,
                    ),

                    TextField(
                      controller:
                          descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization:
                          TextCapitalization
                              .sentences,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Breakdown description',
                        alignLabelWithHint:
                            true,
                        prefixIcon: Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 55,
                          ),
                          child: Icon(
                            Icons
                                .description_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextField(
                      controller:
                          locationController,
                      maxLines: 2,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Breakdown location',
                        prefixIcon:
                            const Icon(
                          Icons.place_outlined,
                        ),
                        suffixIcon:
                            IconButton(
                          tooltip:
                              'Refresh GPS',
                          onPressed:
                              locating
                                  ? null
                                  : refreshGps,
                          icon: locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .my_location_rounded,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextField(
                      controller:
                          landmarkController,
                      maxLength: 120,
                      textCapitalization:
                          TextCapitalization
                              .words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Nearby landmark',
                        prefixIcon:
                            Icon(
                          Icons
                              .signpost_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.md,
                    ),

                    TextField(
                      controller:
                          notesController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Additional notes',
                        alignLabelWithHint:
                            true,
                        prefixIcon: Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 40,
                          ),
                          child: Icon(
                            Icons
                                .notes_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.lg,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Photo evidence',
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                        Text(
                          '${photos.length}/3',
                          style: theme
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color:
                                colors.primary,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: RaSpace.sm,
                    ),

                    if (photos.isNotEmpty)
                      SizedBox(
                        height: 92,
                        child:
                            ListView.separated(
                          scrollDirection:
                              Axis.horizontal,
                          itemCount:
                              photos.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            Widget photo;

                            try {
                              photo =
                                  Image.memory(
                                base64Decode(
                                  photos[index],
                                ),
                                width: 92,
                                height: 92,
                                fit: BoxFit
                                    .cover,
                              );
                            } on FormatException {
                              photo =
                                  const Center(
                                child: Icon(
                                  Icons
                                      .broken_image_outlined,
                                ),
                              );
                            }

                            return Stack(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  clipBehavior:
                                      Clip
                                          .antiAlias,
                                  decoration:
                                      BoxDecoration(
                                    color: colors
                                        .surfaceContainerHighest,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),
                                  child:
                                      photo,
                                ),
                                Positioned(
                                  right: 3,
                                  top: 3,
                                  child:
                                      IconButton
                                          .filled(
                                    visualDensity:
                                        VisualDensity
                                            .compact,
                                    style: IconButton
                                        .styleFrom(
                                      backgroundColor:
                                          Colors
                                              .black
                                              .withValues(
                                        alpha:
                                            .58,
                                      ),
                                      foregroundColor:
                                          Colors
                                              .white,
                                    ),
                                    icon:
                                        const Icon(
                                      Icons
                                          .close_rounded,
                                      size:
                                          15,
                                    ),
                                    onPressed:
                                        () {
                                      setSheetState(
                                        () {
                                          photos.removeAt(
                                            index,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    if (photos.isNotEmpty)
                      const SizedBox(
                        height: RaSpace.sm,
                      ),

                    OutlinedButton.icon(
                      onPressed:
                          preparingPhoto ||
                                  photos.length >=
                                      3
                              ? null
                              : addPhotos,
                      icon: preparingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .add_a_photo_outlined,
                            ),
                      label: Text(
                        photos.length >= 3
                            ? 'Maximum 3 photos added'
                            : 'Add Photos',
                      ),
                    ),

                    const SizedBox(
                      height: RaSpace.xl,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton(
                            onPressed:
                                () =>
                                    Navigator.pop(
                              sheetContext,
                            ),
                            child:
                                const Text(
                              'Cancel',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: RaSpace.sm,
                        ),
                        Expanded(
                          flex: 2,
                          child:
                              FilledButton.icon(
                            onPressed: () {
                              final location =
                                  locationController
                                      .text
                                      .trim();

                              if (location
                                  .isEmpty) {
                                return;
                              }

                              Navigator.pop(
                                sheetContext,
                                editableDraft
                                    .copyWith(
                                  description:
                                      descriptionController
                                          .text
                                          .trim(),
                                  notes:
                                      notesController
                                          .text
                                          .trim(),
                                  location:
                                      location,
                                  landmark:
                                      landmarkController
                                          .text
                                          .trim(),
                                  latitude:
                                      latitude,
                                  longitude:
                                      longitude,
                                  locationAccuracyMeters:
                                      accuracy,
                                  vehiclePhotoUrls:
                                      photos,
                                  photoAnnotations:
                                      listEquals(
                                    photos,
                                    editableDraft
                                        .vehiclePhotoUrls,
                                  )
                                          ? editableDraft
                                              .photoAnnotations
                                          : const [],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .check_rounded,
                            ),
                            label:
                                const Text(
                              'Save Changes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    descriptionController.dispose();
    notesController.dispose();
    locationController.dispose();
    landmarkController.dispose();

    if (updatedDraft == null ||
        !mounted) {
      return;
    }

    try {
      await RequestService()
          .updateSearchingRequest(
        widget.requestId!,
        updatedDraft,
      );

      await RequestDraftStore().save(
        updatedDraft,
      );

      if (!mounted) return;

      setState(() {
        editableDraft = updatedDraft;
        currentLocationLabel =
            updatedDraft.location;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Pending request updated.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to edit. A provider may have already accepted the request.',
          ),
        ),
      );
    }
  }

  Future<void> cancelRequest() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color: colors.errorContainer,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: Icon(
              Icons
                  .close_rounded,
              color: colors.error,
            ),
          ),
          title: const Text(
            'Cancel assistance request?',
          ),
          content: const Text(
            'Provider searching will stop and this request will move to your cancelled request history.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Keep Searching',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Cancel Request',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      cancelling = true;
    });

    try {
      if (widget.requestId != null) {
        await RequestService()
            .cancelRequest(
          widget.requestId!,
        );
      }

      if (!mounted) return;

      replace(
        context,
        const DriverShell(),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        cancelling = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to cancel the request. Try again.',
          ),
        ),
      );
    }
  }

  String get searchTitle {
    if (requestStatus == 'cancelled') {
      return 'Request cancelled';
    }

    if (requestStatus == 'not_submitted') {
      return 'Request not submitted';
    }

    if (searchingAllProviders) {
      return 'Expanding your search';
    }

    if (preferredSearch) {
      return 'Contacting your provider';
    }

    return 'Finding roadside help';
  }

  String get searchMessage {
    if (requestError != null) {
      return requestError!;
    }

    if (requestStatus == 'cancelled') {
      return 'This roadside assistance request is no longer active.';
    }

    if (requestStatus ==
        'not_submitted') {
      return 'Return home and submit a new roadside assistance request.';
    }

    if (searchingAllProviders) {
      return '${editableDraft.provider.isEmpty ? 'The selected provider' : editableDraft.provider} was unavailable. RoadAssist is now checking other suitable providers.';
    }

    if (preferredSearch) {
      return 'Waiting for ${editableDraft.provider.isEmpty ? 'your selected provider' : editableDraft.provider} to review your request.';
    }

    return 'RoadAssist is sharing your request with suitable available providers.';
  }

  RaTone get searchTone {
    if (requestStatus == 'cancelled' ||
        requestStatus ==
            'not_submitted') {
      return RaTone.danger;
    }

    return RaTone.info;
  }

  Widget _buildSearchVisual(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (
          context,
          child,
        ) {
          final value =
              pulseController.value;

          return SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                Transform.scale(
                  scale:
                      .88 + value * .12,
                  child: Container(
                    width: 175,
                    height: 175,
                    decoration:
                        BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary
                          .withValues(
                        alpha:
                            .04 +
                                value *
                                    .035,
                      ),
                    ),
                  ),
                ),

                Transform.scale(
                  scale:
                      .92 + value * .07,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration:
                        BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors
                            .primary
                            .withValues(
                          alpha:
                              .15 +
                                  value *
                                      .15,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 86,
                  height: 86,
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin: Alignment
                          .topLeft,
                      end: Alignment
                          .bottomRight,
                      colors: [
                        colors.primary,
                        const Color(
                          0xFF007D70,
                        ),
                      ],
                    ),
                    shape:
                        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors
                            .primary
                            .withValues(
                          alpha:
                              .22,
                        ),
                        blurRadius:
                            24,
                        offset:
                            const Offset(
                          0,
                          9,
                        ),
                      ),
                    ],
                  ),
                  child: Icon(
                    activelySearching
                        ? Icons
                            .location_searching_rounded
                        : requestStatus ==
                                'cancelled'
                            ? Icons
                                .close_rounded
                            : Icons
                                .info_outline_rounded,
                    color:
                        Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(
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
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .6,
          ),
        ),
      ),
      child: Column(
        children: [
          _RaSearchDetailRow(
            icon:
                Icons.car_repair_outlined,
            label: 'Assistance',
            value:
                editableDraft.issue,
          ),
          const _RaSearchDivider(),
          _RaSearchDetailRow(
            icon:
                Icons.location_on_outlined,
            label:
                'Breakdown location',
            value:
                currentLocationLabel,
          ),
          if (editableDraft.landmark
              .trim()
              .isNotEmpty) ...[
            const _RaSearchDivider(),
            _RaSearchDetailRow(
              icon:
                  Icons.signpost_outlined,
              label: 'Landmark',
              value:
                  editableDraft.landmark,
            ),
          ],
          const _RaSearchDivider(),
          _RaSearchDetailRow(
            icon:
                preferredSearch
                    ? Icons
                        .person_outline_rounded
                    : Icons
                        .compare_arrows_rounded,
            label:
                'Search preference',
            value: preferredSearch
                ? editableDraft.provider
                : 'Suitable available providers',
          ),
          if (widget.requestId != null) ...[
            const _RaSearchDivider(),
            _RaSearchDetailRow(
              icon:
                  Icons.tag_rounded,
              label: 'Request ID',
              value:
                  widget.requestId!,
            ),
          ],
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

    return PopScope(
      canPop: !activelySearching,
      child: Scaffold(
        backgroundColor:
            theme.scaffoldBackgroundColor,

        appBar: AppBar(
          automaticallyImplyLeading:
              !activelySearching,
          title: const Text(
            'Finding Assistance',
          ),
        ),

        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    RaSpace.lg,
                    RaSpace.md,
                    RaSpace.lg,
                    RaSpace.xxl,
                  ),
                  children: [
                    Align(
                      alignment:
                          Alignment.centerRight,
                      child: StatusPill(
                        label: requestStatus ==
                                'cancelled'
                            ? 'CANCELLED'
                            : requestStatus ==
                                    'not_submitted'
                                ? 'NOT SUBMITTED'
                                : searchingAllProviders
                                    ? 'WIDER SEARCH'
                                    : 'SEARCHING',
                        tone:
                            searchTone,
                      ),
                    ),

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    _buildSearchVisual(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    Text(
                      searchTitle,
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          RaSpace.sm,
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            RaSpace.md,
                      ),
                      child: Text(
                        searchMessage,
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: requestError !=
                                  null
                              ? colors.error
                              : colors
                                  .onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),

                    if (activelySearching) ...[
                      const SizedBox(
                        height:
                            RaSpace.lg,
                      ),
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                        child:
                            const LinearProgressIndicator(
                          minHeight: 5,
                        ),
                      ),
                    ],

                    if (preferredSearch &&
                        activelySearching) ...[
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
                            alpha: .34,
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
                                  .schedule_outlined,
                              color: colors
                                  .primary,
                              size: 20,
                            ),
                            const SizedBox(
                              width:
                                  RaSpace.sm,
                            ),
                            Expanded(
                              child: Text(
                                'If your selected provider does not respond within 90 seconds, RoadAssist will automatically widen the search.',
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  height:
                                      1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    Text(
                      'Your request',
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
                      height:
                          RaSpace.md,
                    ),

                    _buildSummary(
                      context,
                    ),

                    if (widget.requestId !=
                        null) ...[
                      const SizedBox(
                        height:
                            RaSpace.xxl,
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons
                                .request_quote_outlined,
                            color: colors
                                .primary,
                          ),
                          const SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          Expanded(
                            child: Text(
                              'Provider offers',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),

                      QuoteOffers(
                        requestId:
                            widget
                                .requestId!,
                      ),
                    ],
                  ],
                ),
              ),

              _RaSearchBottomBar(
                searching:
                    activelySearching,
                cancelling:
                    cancelling,
                onEdit:
                    editPendingRequest,
                onCancel:
                    cancelRequest,
                onHome: () =>
                    replace(
                  context,
                  const DriverShell(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaSearchDetailRow
    extends StatelessWidget {
  const _RaSearchDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: RaSpace.sm,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: colors.primary,
              size: 20,
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
                  label,
                  style: theme
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                    height: 1.35,
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

class _RaSearchDivider
    extends StatelessWidget {
  const _RaSearchDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(
            alpha: .5,
          ),
    );
  }
}

class _RaSearchBottomBar
    extends StatelessWidget {
  const _RaSearchBottomBar({
    required this.searching,
    required this.cancelling,
    required this.onEdit,
    required this.onCancel,
    required this.onHome,
  });

  final bool searching;
  final bool cancelling;

  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onHome;

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
                .withValues(
              alpha: .6,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: searching
            ? Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          cancelling
                              ? null
                              : onEdit,
                      icon:
                          const Icon(
                        Icons
                            .edit_outlined,
                      ),
                      label:
                          const Text(
                        'Edit Request',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width:
                        RaSpace.sm,
                  ),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      style:
                          OutlinedButton
                              .styleFrom(
                        foregroundColor:
                            colors.error,
                        side:
                            BorderSide(
                          color: colors
                              .error
                              .withValues(
                            alpha: .45,
                          ),
                        ),
                      ),
                      onPressed:
                          cancelling
                              ? null
                              : onCancel,
                      icon: cancelling
                          ? const SizedBox(
                              width: 17,
                              height:
                                  17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .close_rounded,
                            ),
                      label:
                          const Text(
                        'Cancel',
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      onHome,
                  icon:
                      const Icon(
                    Icons
                        .home_outlined,
                  ),
                  label:
                      const Text(
                    'Back to Home',
                  ),
                ),
              ),
      ),
    );
  }
}