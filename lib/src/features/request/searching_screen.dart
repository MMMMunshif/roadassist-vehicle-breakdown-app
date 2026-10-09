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

class _SearchingScreenState
    extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<
      DocumentSnapshot<Map<String, dynamic>>>?
      requestListener;

  Timer? providerResponseTimer;

  late final AnimationController
      pulseController;

  String requestStatus =
      'searching';

  String? requestError;

  bool searchingAllProviders =
      false;

  bool navigatingToTracking =
      false;

  bool cancelling = false;

  bool expandingSearch = false;

  late String currentLocationLabel;

  late RequestDraft editableDraft;

  bool get activelySearching =>
      requestStatus == 'searching';

  bool get preferredSearch =>
      editableDraft
          .preferredProviderId
          .trim()
          .isNotEmpty &&
      !searchingAllProviders;

  @override
  void initState() {
    super.initState();

    editableDraft =
        widget.draft;

    currentLocationLabel =
        widget.draft.location;

    pulseController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1500,
      ),
    )..repeat(
            reverse: true,
          );

    if (widget.requestId == null) {
      requestStatus =
          'not_submitted';

      requestError =
          'This request is not connected to the live assistance system.';

      return;
    }

    requestListener =
        RequestService()
            .watchRequest(
      widget.requestId!,
    )
            .listen(
      handleRequestUpdate,
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

  void handleRequestUpdate(
    DocumentSnapshot<
            Map<String, dynamic>>
        snapshot,
  ) {
    final data =
        snapshot.data();

    if (!mounted) return;

    if (data == null) {
      setState(() {
        requestError =
            'This assistance request could not be found.';
      });

      return;
    }

    final status =
        data['status']
                as String? ??
            'searching';

    final locationLabel =
        data['locationLabel']
                as String? ??
            editableDraft.location;

    final preferredProviderId =
        data['preferredProviderId']
                as String? ??
            '';

    if (status == 'searching' &&
        preferredProviderId
            .isNotEmpty) {
      scheduleProviderTimeout(
        data,
      );
    } else {
      providerResponseTimer
          ?.cancel();

      providerResponseTimer =
          null;
    }

    if (const [
          'accepted',
          'en_route',
          'arrived',
          'completed',
        ].contains(
          status,
        ) &&
        !navigatingToTracking) {
      navigatingToTracking =
          true;

      final latitude =
          (data['latitude']
                  as num?)
              ?.toDouble();

      final longitude =
          (data['longitude']
                  as num?)
              ?.toDouble();

      final trackingDraft =
          editableDraft.copyWith(
        location:
            locationLabel,
        landmark:
            data['landmark']
                    as String? ??
                editableDraft
                    .landmark,
        locationAccuracyMeters:
            (data['locationAccuracyMeters']
                    as num?)
                ?.toDouble(),
        latitude:
            latitude,
        longitude:
            longitude,
      );

      replace(
        context,
        TrackingScreen(
          draft:
              trackingDraft,
          requestId:
              widget.requestId,
        ),
      );

      return;
    }

    setState(() {
      requestStatus = status;

      currentLocationLabel =
          locationLabel;

      editableDraft =
          editableDraft.copyWith(
        description:
            data['description']
                    as String? ??
                editableDraft
                    .description,
        notes:
            data['notes']
                    as String? ??
                editableDraft
                    .notes,
        location:
            locationLabel,
        landmark:
            data['landmark']
                    as String? ??
                editableDraft
                    .landmark,
        vehiclePhotoUrls:
            (data['vehiclePhotoUrls']
                        as List<dynamic>? ??
                    const [])
                .whereType<String>()
                .toList(),
      );

      requestError = null;

      searchingAllProviders =
          widget.draft
                  .preferredProviderId
                  .isNotEmpty &&
              preferredProviderId
                  .isEmpty;
    });
  }

  void scheduleProviderTimeout(
    Map<String, dynamic> data,
  ) {
    if (providerResponseTimer !=
            null ||
        widget.requestId == null) {
      return;
    }

    const responseWindow =
        Duration(
      seconds: 90,
    );

    final createdAt =
        (data['createdAt']
                as Timestamp?)
            ?.toDate();

    final elapsed =
        createdAt == null
            ? Duration.zero
            : DateTime.now()
                .difference(
                createdAt,
              );

    final remaining =
        elapsed >= responseWindow
            ? Duration.zero
            : responseWindow -
                elapsed;

    providerResponseTimer =
        Timer(
      remaining,
      () async {
        providerResponseTimer =
            null;

        try {
          await RequestService()
              .expandProviderSearch(
            widget.requestId!,
          );
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to expand the provider search yet.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void>
      expandSearchNow() async {
    if (widget.requestId == null ||
        expandingSearch ||
        !activelySearching) {
      return;
    }

    setState(() {
      expandingSearch = true;
    });

    try {
      await RequestService()
          .expandProviderSearch(
        widget.requestId!,
      );

      if (!mounted) return;

      setState(() {
        searchingAllProviders =
            true;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Provider search expanded.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to expand the provider search right now.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          expandingSearch = false;
        });
      }
    }
  }

  Future<void>
      editPendingRequest() async {
    if (widget.requestId == null ||
        requestStatus !=
            'searching') {
      return;
    }

    final descriptionController =
        TextEditingController(
      text:
          editableDraft.description,
    );

    final notesController =
        TextEditingController(
      text:
          editableDraft.notes,
    );

    final locationController =
        TextEditingController(
      text:
          editableDraft.location,
    );

    final landmarkController =
        TextEditingController(
      text:
          editableDraft.landmark,
    );

    final photos =
        List<String>.from(
      editableDraft
          .vehiclePhotoUrls,
    );

    double latitude =
        editableDraft.latitude;

    double longitude =
        editableDraft.longitude;

    double? accuracy =
        editableDraft
            .locationAccuracyMeters;

    bool locating = false;
    bool preparingPhotos =
        false;

    final updatedDraft =
        await showModalBottomSheet<
            RequestDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            Future<void>
                refreshGps() async {
              setSheetState(() {
                locating = true;
              });

              try {
                var permission =
                    await Geolocator
                        .checkPermission();

                if (permission ==
                    LocationPermission
                        .denied) {
                  permission =
                      await Geolocator
                          .requestPermission();
                }

                if (permission ==
                        LocationPermission
                            .denied ||
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
                        LocationAccuracy
                            .high,
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
                if (sheetContext
                    .mounted) {
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
                if (sheetContext
                    .mounted) {
                  setSheetState(() {
                    locating = false;
                  });
                }
              }
            }

            Future<void>
                addPhotos() async {
              if (preparingPhotos ||
                  photos.length >=
                      3) {
                return;
              }

              setSheetState(() {
                preparingPhotos =
                    true;
              });

              try {
                final picked =
                    await ImagePicker()
                        .pickMultiImage(
                  imageQuality: 75,
                  maxWidth: 1600,
                  limit:
                      3 - photos.length,
                );

                for (final photo
                    in picked) {
                  if (photos.length >=
                      3) {
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
                    photos.add(
                      encoded,
                    );
                  }
                }
              } finally {
                if (sheetContext
                    .mounted) {
                  setSheetState(() {
                    preparingPhotos =
                        false;
                  });
                }
              }
            }

            return Padding(
              padding:
                  EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(
                            sheetContext,
                          ).height *
                          .92,
                ),
                decoration:
                    BoxDecoration(
                  color: dark
                      ? const Color(
                          0xFF0D1D2B,
                        )
                      : colors.surface,
                  borderRadius:
                      const BorderRadius
                          .vertical(
                    top:
                        Radius.circular(
                      28,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        18,
                        12,
                        18,
                        8,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child:
                                Container(
                              width: 42,
                              height: 4,
                              decoration:
                                  BoxDecoration(
                                color: colors
                                    .onSurfaceVariant
                                    .withValues(
                                  alpha:
                                      .24,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  999,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height:
                                18,
                          ),

                          Row(
                            children: [
                              Container(
                                width:
                                    46,
                                height:
                                    46,
                                decoration:
                                    BoxDecoration(
                                  color: colors
                                      .primary
                                      .withValues(
                                    alpha:
                                        .09,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    14,
                                  ),
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .edit_note_rounded,
                                  color: colors
                                      .primary,
                                ),
                              ),

                              const SizedBox(
                                width:
                                    11,
                              ),

                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      'Edit pending request',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            17,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          3,
                                    ),
                                    Text(
                                      'You can update these details until a provider accepts.',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            9,
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          10,
                          18,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: [
                            TextField(
                              controller:
                                  descriptionController,
                              minLines:
                                  3,
                              maxLines:
                                  5,
                              maxLength:
                                  500,
                              textCapitalization:
                                  TextCapitalization
                                      .sentences,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Breakdown description',
                                alignLabelWithHint:
                                    true,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            TextField(
                              controller:
                                  notesController,
                              maxLines:
                                  3,
                              maxLength:
                                  300,
                              textCapitalization:
                                  TextCapitalization
                                      .sentences,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Additional notes',
                                alignLabelWithHint:
                                    true,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            TextField(
                              controller:
                                  locationController,
                              minLines:
                                  1,
                              maxLines:
                                  2,
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Location',
                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .location_on_outlined,
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
                                      ? const SizedBox.square(
                                          dimension:
                                              16,
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
                              height: 10,
                            ),

                            TextField(
                              controller:
                                  landmarkController,
                              maxLength:
                                  120,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Landmark',
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .signpost_outlined,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 17,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      Text(
                                    'Photo evidence',
                                    style: GoogleFonts
                                        .plusJakartaSans(
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${photos.length}/3',
                                  style: GoogleFonts
                                      .plusJakartaSans(
                                    fontSize:
                                        8.5,
                                    color: colors
                                        .primary,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            if (photos
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 9,
                              ),

                              SizedBox(
                                height:
                                    90,
                                child: ListView
                                    .separated(
                                  scrollDirection:
                                      Axis.horizontal,
                                  itemCount:
                                      photos.length,
                                  separatorBuilder:
                                      (
                                    context,
                                    index,
                                  ) =>
                                          const SizedBox(
                                    width:
                                        7,
                                  ),
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    Widget image;

                                    try {
                                      image = Image.memory(
                                        base64Decode(
                                          photos[index],
                                        ),
                                        width:
                                            90,
                                        height:
                                            90,
                                        fit:
                                            BoxFit.cover,
                                      );
                                    } on FormatException {
                                      image = Container(
                                        width:
                                            90,
                                        height:
                                            90,
                                        alignment:
                                            Alignment.center,
                                        child:
                                            const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      );
                                    }

                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(
                                            13,
                                          ),
                                          child:
                                              image,
                                        ),
                                        Positioned(
                                          top:
                                              2,
                                          right:
                                              2,
                                          child:
                                              IconButton.filled(
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize:
                                                13,
                                            style:
                                                IconButton.styleFrom(
                                              minimumSize:
                                                  const Size(
                                                27,
                                                27,
                                              ),
                                              backgroundColor:
                                                  Colors.black.withValues(
                                                alpha:
                                                    .60,
                                              ),
                                              foregroundColor:
                                                  Colors.white,
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
                                            icon:
                                                const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(
                              height: 10,
                            ),

                            OutlinedButton.icon(
                              onPressed:
                                  preparingPhotos ||
                                          photos.length >=
                                              3
                                      ? null
                                      : addPhotos,
                              icon: preparingPhotos
                                  ? const SizedBox.square(
                                      dimension:
                                          16,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .add_a_photo_outlined,
                                    ),
                              label: const Text(
                                'Add Photo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        18,
                        8,
                        18,
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        border:
                            Border(
                          top:
                              BorderSide(
                            color: colors
                                .outlineVariant
                                .withValues(
                              alpha:
                                  .40,
                            ),
                          ),
                        ),
                      ),
                      child:
                          FilledButton.icon(
                        onPressed:
                            () {
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
                                  List<String>.from(
                                photos,
                              ),
                            ),
                          );
                        },
                        icon:
                            const Icon(
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
        editableDraft =
            updatedDraft;

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

  Future<void>
      cancelRequest() async {
    if (cancelling) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        final colors =
            Theme.of(
          dialogContext,
        ).colorScheme;

        return AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color: colors.error
                  .withValues(
                alpha: .09,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                17,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              color: colors.error,
            ),
          ),
          title: const Text(
            'Cancel assistance request?',
          ),
          content: const Text(
            'Provider searching will stop and this request will move to cancelled request history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
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
      if (widget.requestId !=
          null) {
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to cancel the request. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cancelling = false;
        });
      }
    }
  }

  String get searchTitle {
    if (requestStatus ==
        'cancelled') {
      return 'Request cancelled';
    }

    if (requestStatus ==
        'not_submitted') {
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

    if (requestStatus ==
        'cancelled') {
      return 'This roadside assistance request is no longer active.';
    }

    if (requestStatus ==
        'not_submitted') {
      return 'Return home and submit a new roadside assistance request.';
    }

    if (searchingAllProviders) {
      return 'RoadAssist is now checking other suitable available providers.';
    }

    if (preferredSearch) {
      final name =
          editableDraft.provider
                  .trim()
                  .isEmpty
              ? 'your selected provider'
              : editableDraft.provider;

      return 'Waiting for $name to review your request.';
    }

    return 'RoadAssist is sharing your request with suitable available providers.';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return RaScaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        title: Text(
          'Finding Assistance',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        actions: [
          if (activelySearching)
            IconButton(
              tooltip:
                  'Edit pending request',
              onPressed:
                  editPendingRequest,
              icon: const Icon(
                Icons
                    .edit_outlined,
              ),
            ),

          const SizedBox(
            width: 4,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics:
                    const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  28,
                ),
                children: [
                  _RaSearchingHero(
                    controller:
                        pulseController,
                    title:
                        searchTitle,
                    message:
                        searchMessage,
                    active:
                        activelySearching,
                    error:
                        requestError !=
                            null,
                  ),

                  const SizedBox(
                    height: 17,
                  ),

                  if (preferredSearch &&
                      activelySearching)
                    _RaPreferredProviderSearch(
                      providerName:
                          editableDraft
                              .provider,
                      expanding:
                          expandingSearch,
                      onExpand:
                          expandSearchNow,
                    ),

                  if (preferredSearch &&
                      activelySearching)
                    const SizedBox(
                      height: 13,
                    ),

                  _RaSearchRequestCard(
                    issue:
                        editableDraft
                            .issue,
                    priority:
                        requestPriorityLabel(
                      editableDraft
                          .priority,
                    ),
                    location:
                        currentLocationLabel,
                    vehicle:
                        editableDraft
                            .modelYear,
                    registration:
                        editableDraft
                            .registration,
                  ),

                  if (requestError !=
                      null) ...[
                    const SizedBox(
                      height: 13,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .all(
                        13,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .error
                            .withValues(
                          alpha: .07,
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
                                .cloud_off_outlined,
                            color:
                                colors.error,
                            size: 19,
                          ),

                          const SizedBox(
                            width: 9,
                          ),

                          Expanded(
                            child: Text(
                              requestError!,
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize:
                                    9.5,
                                height:
                                    1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (activelySearching &&
                      widget.requestId !=
                          null) ...[
                    const SizedBox(
                      height: 27,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Provider offers',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing:
                                      -.35,
                                ),
                              ),

                              const SizedBox(
                                height:
                                    3,
                              ),

                              Text(
                                'Offers appear here as providers respond.',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize:
                                      9.5,
                                  color: colors
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    QuoteOffers(
                      requestId:
                          widget.requestId!,
                    ),
                  ],

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      13,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors.primary
                          .withValues(
                        alpha: .055,
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
                              .notifications_active_outlined,
                          color:
                              colors.primary,
                          size: 19,
                        ),

                        const SizedBox(
                          width: 9,
                        ),

                        Expanded(
                          child: Text(
                            'You can leave this screen. RoadAssist notifications and the Requests tab will continue showing request updates.',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize:
                                  9.5,
                              height:
                                  1.45,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _RaSearchBottomBar(
              active:
                  activelySearching,
              cancelling:
                  cancelling,
              onCancel:
                  cancelRequest,
              onHome: () {
                replace(
                  context,
                  const DriverShell(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RaSearchingHero
    extends StatelessWidget {
  const _RaSearchingHero({
    required this.controller,
    required this.title,
    required this.message,
    required this.active,
    required this.error,
  });

  final AnimationController
      controller;

  final String title;
  final String message;

  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final tone = error
        ? colors.error
        : colors.primary;

    return Container(
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: .07,
        ),
        borderRadius:
            BorderRadius.circular(
          25,
        ),
        border: Border.all(
          color: tone.withValues(
            alpha: .16,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 135,
            child:
                AnimatedBuilder(
              animation:
                  controller,
              builder: (
                context,
                child,
              ) {
                final pulse = active
                    ? .84 +
                        controller
                                .value *
                            .16
                    : 1.0;

                return Transform.scale(
                  scale: pulse,
                  child: Stack(
                    alignment:
                        Alignment.center,
                    children: [
                      Container(
                        width: 125,
                        height: 125,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color: tone
                              .withValues(
                            alpha: .035,
                          ),
                          border:
                              Border.all(
                            color: tone
                                .withValues(
                              alpha: .09,
                            ),
                          ),
                        ),
                      ),

                      Container(
                        width: 86,
                        height: 86,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color: tone
                              .withValues(
                            alpha: .07,
                          ),
                        ),
                      ),

                      Container(
                        width: 56,
                        height: 56,
                        decoration:
                            BoxDecoration(
                          color: tone,
                          shape:
                              BoxShape.circle,
                        ),
                        child: Icon(
                          error
                              ? Icons
                                  .cloud_off_outlined
                              : active
                                  ? Icons
                                      .person_search_outlined
                                  : Icons
                                      .info_outline_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 9.8,
              height: 1.45,
              color: colors
                  .onSurfaceVariant,
            ),
          ),

          if (active) ...[
            const SizedBox(
              height: 14,
            ),

            ClipRRect(
              borderRadius:
                  BorderRadius
                      .circular(
                999,
              ),
              child:
                  const LinearProgressIndicator(
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RaPreferredProviderSearch
    extends StatelessWidget {
  const _RaPreferredProviderSearch({
    required this.providerName,
    required this.expanding,
    required this.onExpand,
  });

  final String providerName;
  final bool expanding;

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final name =
        providerName.trim().isEmpty
            ? 'Selected provider'
            : providerName;

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileInitials(
                name: name,
                radius: 21,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Waiting for this provider to respond.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.8,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 11,
          ),

          SizedBox(
            width:
                double.infinity,
            child:
                OutlinedButton.icon(
              onPressed:
                  expanding
                      ? null
                      : onExpand,
              icon: expanding
                  ? const SizedBox
                      .square(
                      dimension: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .person_search_outlined,
                    ),
              label: const Text(
                'Search Other Providers Now',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaSearchRequestCard
    extends StatelessWidget {
  const _RaSearchRequestCard({
    required this.issue,
    required this.priority,
    required this.location,
    required this.vehicle,
    required this.registration,
  });

  final String issue;
  final String priority;
  final String location;
  final String vehicle;
  final String registration;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        children: [
          _RaSearchDetailRow(
            icon: Icons
                .car_repair_outlined,
            label:
                'Assistance',
            value: issue,
          ),

          const _RaSearchDivider(),

          _RaSearchDetailRow(
            icon: Icons
                .priority_high_rounded,
            label:
                'Priority',
            value: priority,
          ),

          const _RaSearchDivider(),

          _RaSearchDetailRow(
            icon: Icons
                .directions_car_outlined,
            label:
                'Vehicle',
            value: [
              vehicle,
              registration
                  .toUpperCase(),
            ]
                .where(
                  (value) => value
                      .trim()
                      .isNotEmpty,
                )
                .join(' • '),
          ),

          const _RaSearchDivider(),

          _RaSearchDetailRow(
            icon: Icons
                .location_on_outlined,
            label:
                'Location',
            value: location,
          ),
        ],
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
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            color:
                colors.primary,
            size: 18,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  label,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.5,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.2,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w600,
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
    final colors =
        Theme.of(context)
            .colorScheme;

    return Divider(
      height: 1,
      indent: 28,
      color: colors
          .outlineVariant
          .withValues(
        alpha: .34,
      ),
    );
  }
}

class _RaSearchBottomBar
    extends StatelessWidget {
  const _RaSearchBottomBar({
    required this.active,
    required this.cancelling,
    required this.onCancel,
    required this.onHome,
  });

  final bool active;
  final bool cancelling;

  final VoidCallback onCancel;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors
                .outlineVariant
                .withValues(
              alpha: .45,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: active
            ? OutlinedButton.icon(
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      colors.error,
                ),
                onPressed:
                    cancelling
                        ? null
                        : onCancel,
                icon: cancelling
                    ? const SizedBox
                        .square(
                        dimension: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .close_rounded,
                      ),
                label: const Text(
                  'Cancel Assistance Request',
                ),
              )
            : FilledButton.icon(
                onPressed:
                    onHome,
                icon: const Icon(
                  Icons
                      .home_outlined,
                ),
                label: const Text(
                  'Return Home',
                ),
              ),
      ),
    );
  }
}