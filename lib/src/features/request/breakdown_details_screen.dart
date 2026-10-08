part of '../../screens.dart';

class BreakdownDetailsScreen extends StatefulWidget {
  const BreakdownDetailsScreen({
    super.key,
    required this.issues,
    this.initialDraft,
  });

  final List<String> issues;
  final RequestDraft? initialDraft;

  @override
  State<BreakdownDetailsScreen> createState() =>
      _BreakdownDetailsScreenState();
}

class _BreakdownDetailsScreenState extends State<BreakdownDetailsScreen> {
  final formKey = GlobalKey<FormState>();

  final modelController = TextEditingController();
  final registrationController = TextEditingController();
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();
  final customVehicleController = TextEditingController();

  String vehicle = 'Sedan / Hatchback';
  String? vehicleId;
  Map<String, dynamic>? vehicleSnapshot;

  final List<String> vehiclePhotoUrls = [];
  final List<BreakdownPhotoAnnotation> photoAnnotations = [];

  bool uploadingVehiclePhoto = false;

  final SpeechToText speechToText = SpeechToText();
  bool listeningForDescription = false;

  String priority = 'normal';
  String partsPreference = 'discuss';

  Timer? draftSaveDebounce;

  @override
  void initState() {
    super.initState();

    final draft = widget.initialDraft;

    if (draft == null) {
      if (signedIn) {
        loadDefaultVehicle();
      }
      return;
    }

    vehicleId = draft.vehicleId;
    vehicleSnapshot = draft.vehicleSnapshot;

    const standardTypes = {
      'Sedan / Hatchback',
      'SUV',
      'Van',
      'Motorcycle',
    };

    if (standardTypes.contains(draft.vehicleType)) {
      vehicle = draft.vehicleType;
    } else {
      vehicle = 'Other';
      customVehicleController.text = draft.vehicleType;
    }

    modelController.text = draft.modelYear;
    registrationController.text = draft.registration;
    descriptionController.text = draft.description;
    notesController.text = draft.notes;

    priority = draft.priority;
    partsPreference = draft.partsPreference;

    vehiclePhotoUrls.addAll(
      draft.vehiclePhotoUrls,
    );

    photoAnnotations.addAll(
      draft.photoAnnotations,
    );
  }

  @override
  void dispose() {
    draftSaveDebounce?.cancel();

    speechToText.stop();

    modelController.dispose();
    registrationController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    customVehicleController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VEHICLE
  // ---------------------------------------------------------------------------

  Future<void> selectSavedVehicle() async {
    final selected =
        await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(
        builder: (_) =>
            const VehiclesScreen(
          selecting: true,
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    applyVehicle(selected);
    scheduleDraftSave();
  }

  void applyVehicle(
    Vehicle selected,
  ) {
    setState(() {
      vehicleId = selected.id;
      vehicleSnapshot = selected.toJson();

      vehicle = selected.vehicleType;

      if (vehicle == 'Other') {
        customVehicleController.text =
            selected.vehicleType;
      }

      modelController.text =
          selected.label;

      registrationController.text =
          selected.registration;
    });
  }

  Future<void> loadDefaultVehicle() async {
    try {
      final selected =
          await VehicleService()
              .loadDefault();

      if (selected != null &&
          mounted &&
          modelController.text.isEmpty &&
          registrationController
              .text.isEmpty) {
        applyVehicle(selected);
      }
    } catch (_) {
      // Manual entry remains available.
    }
  }

  // ---------------------------------------------------------------------------
  // DRAFT
  // ---------------------------------------------------------------------------

  RequestDraft buildDraft() {
    final actualVehicleType =
        vehicle == 'Other'
            ? customVehicleController
                .text
                .trim()
            : vehicle;

    return RequestDraft(
      vehicleId: vehicleId,
      vehicleSnapshot:
          vehicleSnapshot == null
              ? null
              : {
                  ...vehicleSnapshot!,
                  'vehicleType':
                      actualVehicleType,
                  'modelYear':
                      modelController.text
                          .trim(),
                  'registration':
                      normalizeVehicleRegistration(
                    registrationController
                        .text,
                  ),
                },
      issues: widget.issues,
      vehicleType:
          actualVehicleType,
      modelYear:
          modelController.text.trim(),
      registration:
          normalizeVehicleRegistration(
        registrationController.text,
      ),
      description:
          descriptionController.text
              .trim(),
      notes:
          notesController.text.trim(),
      priority: priority,
      partsPreference:
          partsPreference,
      location:
          widget.initialDraft?.location ??
              'Select current GPS or enter location manually',
      landmark:
          widget.initialDraft?.landmark ??
              '',
      locationAccuracyMeters:
          widget.initialDraft
              ?.locationAccuracyMeters,
      latitude:
          widget.initialDraft
                  ?.latitude ??
              6.9271,
      longitude:
          widget.initialDraft
                  ?.longitude ??
              79.8612,
      provider:
          widget.initialDraft?.provider ??
              '',
      preferredProviderId:
          widget.initialDraft
                  ?.preferredProviderId ??
              '',
      vehiclePhotoUrls:
          List.unmodifiable(
        vehiclePhotoUrls,
      ),
      photoAnnotations:
          List.unmodifiable(
        photoAnnotations,
      ),
    );
  }

  Future<void> saveDraft({
    bool showConfirmation = true,
  }) async {
    await RequestDraftStore().save(
      buildDraft(),
    );

    if (!mounted ||
        !showConfirmation) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Request saved as a draft.',
        ),
      ),
    );
  }

  void scheduleDraftSave() {
    draftSaveDebounce?.cancel();

    draftSaveDebounce = Timer(
      const Duration(
        milliseconds: 600,
      ),
      () => RequestDraftStore()
          .save(buildDraft()),
    );
  }

  // ---------------------------------------------------------------------------
  // VOICE DESCRIPTION
  // ---------------------------------------------------------------------------

  Future<void>
      toggleDescriptionDictation() async {
    if (listeningForDescription) {
      await speechToText.stop();

      if (mounted) {
        setState(() {
          listeningForDescription =
              false;
        });
      }

      scheduleDraftSave();
      return;
    }

    final available =
        await speechToText.initialize(
      onStatus: (status) {
        if (mounted &&
            (status == 'done' ||
                status ==
                    'notListening')) {
          setState(() {
            listeningForDescription =
                false;
          });

          scheduleDraftSave();
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            listeningForDescription =
                false;
          });
        }
      },
    );

    if (!available || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable. Check microphone permission.',
            ),
          ),
        );
      }

      return;
    }

    setState(() {
      listeningForDescription = true;
    });

    await speechToText.listen(
      onResult: (result) {
        if (!mounted ||
            result.recognizedWords
                .trim()
                .isEmpty) {
          return;
        }

        setState(() {
          descriptionController.text =
              result.recognizedWords;
        });
      },
      listenOptions:
          SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode:
            ListenMode.dictation,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHOTOS
  // ---------------------------------------------------------------------------

  Future<void>
      addVehiclePhotos() async {
    if (uploadingVehiclePhoto ||
        vehiclePhotoUrls.length >= 3) {
      return;
    }

    final navigator =
        Navigator.of(context);

    final remainingSlots =
        3 - vehiclePhotoUrls.length;

    final source =
        await showModalBottomSheet<
            ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              RaSpace.lg,
              0,
              RaSpace.lg,
              RaSpace.lg,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
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
                                .circular(
                          16,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .add_a_photo_outlined,
                        color: theme
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(
                      width:
                          RaSpace.md,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Add breakdown evidence',
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
                            '$remainingSlots of 3 photo slots remaining',
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
                _RaBreakdownPhotoSource(
                  icon: Icons
                      .photo_library_outlined,
                  title:
                      'Choose from gallery',
                  subtitle:
                      'Select one or more existing photos',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(
                  height: RaSpace.sm,
                ),
                _RaBreakdownPhotoSource(
                  icon: Icons
                      .camera_alt_outlined,
                  title:
                      'Take a photo',
                  subtitle:
                      'Use your camera to capture the problem',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.camera,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null ||
        !mounted) {
      return;
    }

    setState(() {
      uploadingVehiclePhoto = true;
    });

    try {
      final picker =
          ImagePicker();

      final List<XFile> photos;

      if (source ==
          ImageSource.gallery) {
        photos =
            await picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1600,
          limit: remainingSlots,
        );
      } else {
        final cameraPhoto =
            await navigator.push<XFile>(
          MaterialPageRoute(
            builder: (_) =>
                const CameraCaptureScreen(),
          ),
        );

        photos = cameraPhoto == null
            ? <XFile>[]
            : [cameraPhoto];
      }

      if (photos.isEmpty) {
        return;
      }

      final preparedPhotos =
          <String>[];

      for (final photo in photos) {
        final photoData =
            await PhotoUploadService()
                .prepareVehiclePhoto(
          photo,
        );

        if (!vehiclePhotoUrls
                .contains(photoData) &&
            !preparedPhotos
                .contains(photoData)) {
          preparedPhotos.add(
            photoData,
          );
        }

        if (preparedPhotos.length >=
            remainingSlots) {
          break;
        }
      }

      if (!mounted ||
          preparedPhotos.isEmpty) {
        return;
      }

      setState(() {
        vehiclePhotoUrls.addAll(
          preparedPhotos,
        );
      });

      await saveDraft(
        showConfirmation: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            preparedPhotos.length == 1
                ? 'Breakdown photo added.'
                : '${preparedPhotos.length} breakdown photos added.',
          ),
        ),
      );

      if (photos.length >
          preparedPhotos.length) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Duplicate photos were skipped.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Photo upload failed: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingVehiclePhoto =
              false;
        });
      }
    }
  }

  BreakdownPhotoAnnotation?
      _annotationForPhoto(
    int index,
  ) {
    for (final annotation
        in photoAnnotations) {
      if (annotation.photoIndex ==
          index) {
        return annotation;
      }
    }

    return null;
  }

  Future<void>
      annotateVehiclePhoto(
    int index,
  ) async {
    final existing =
        _annotationForPhoto(index);

    var markerX =
        existing?.markerX ?? .5;

    var markerY =
        existing?.markerY ?? .5;

    final noteController =
        TextEditingController(
      text: existing?.note ?? '',
    );

    final annotation =
        await showDialog<
            BreakdownPhotoAnnotation>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final theme =
                Theme.of(context);

            final colors =
                theme.colorScheme;

            return Dialog(
              insetPadding:
                  const EdgeInsets
                      .all(
                RaSpace.lg,
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 520,
                ),
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .all(
                    RaSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .errorContainer,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                            child: Icon(
                              Icons
                                  .edit_location_alt_outlined,
                              color: colors
                                  .error,
                            ),
                          ),
                          const SizedBox(
                            width:
                                RaSpace
                                    .md,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Mark the damaged area',
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
                                  'Tap the photo to position the marker.',
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
                        height:
                            RaSpace.lg,
                      ),

                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child:
                            LayoutBuilder(
                          builder: (
                            context,
                            constraints,
                          ) {
                            return GestureDetector(
                              onTapDown:
                                  (details) {
                                setDialogState(
                                  () {
                                    markerX = (details
                                                .localPosition
                                                .dx /
                                            constraints
                                                .maxWidth)
                                        .clamp(
                                      0.0,
                                      1.0,
                                    );

                                    markerY = (details
                                                .localPosition
                                                .dy /
                                            constraints
                                                .maxHeight)
                                        .clamp(
                                      0.0,
                                      1.0,
                                    );
                                  },
                                );
                              },
                              child:
                                  ClipRRect(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  18,
                                ),
                                child: Stack(
                                  fit: StackFit
                                      .expand,
                                  children: [
                                    Image.memory(
                                      base64Decode(
                                        vehiclePhotoUrls[
                                            index],
                                      ),
                                      fit: BoxFit
                                          .cover,
                                      errorBuilder:
                                          (
                                        _,
                                        __,
                                        ___,
                                      ) {
                                        return Container(
                                          color: colors
                                              .surfaceContainerHighest,
                                          alignment:
                                              Alignment.center,
                                          child:
                                              const Icon(
                                            Icons
                                                .broken_image_outlined,
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      left: markerX *
                                              constraints
                                                  .maxWidth -
                                          18,
                                      top: markerY *
                                              constraints
                                                  .maxHeight -
                                          34,
                                      child:
                                          Icon(
                                        Icons
                                            .location_on_rounded,
                                        color: colors
                                            .error,
                                        size: 38,
                                        shadows:
                                            const [
                                          Shadow(
                                            color:
                                                Colors.white,
                                            blurRadius:
                                                5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .all(
                          RaSpace.sm,
                        ),
                        decoration:
                            BoxDecoration(
                          color: colors
                              .primaryContainer
                              .withValues(
                            alpha: .35,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .touch_app_outlined,
                              size: 18,
                              color: colors
                                  .primary,
                            ),
                            const SizedBox(
                              width:
                                  RaSpace
                                      .sm,
                            ),
                            const Expanded(
                              child: Text(
                                'Tap directly on the visible damaged area.',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),

                      TextField(
                        controller:
                            noteController,
                        maxLength: 120,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Damage note',
                          hintText:
                              'Example: Deep cut on rear-left tyre',
                          alignLabelWithHint:
                              true,
                        ),
                      ),

                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton(
                              onPressed:
                                  () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                              child:
                                  const Text(
                                'Cancel',
                              ),
                            ),
                          ),
                          const SizedBox(
                            width:
                                RaSpace
                                    .sm,
                          ),
                          Expanded(
                            flex: 2,
                            child:
                                FilledButton.icon(
                              onPressed:
                                  () {
                                Navigator.pop(
                                  dialogContext,
                                  BreakdownPhotoAnnotation(
                                    photoIndex:
                                        index,
                                    markerX:
                                        markerX,
                                    markerY:
                                        markerY,
                                    note:
                                        noteController
                                            .text
                                            .trim(),
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
                                'Save Marker',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();

    if (annotation == null ||
        !mounted) {
      return;
    }

    setState(() {
      photoAnnotations.removeWhere(
        (item) =>
            item.photoIndex == index,
      );

      photoAnnotations.add(
        annotation,
      );
    });

    await saveDraft(
      showConfirmation: false,
    );
  }

  void removeVehiclePhoto(
    int index,
  ) {
    setState(() {
      vehiclePhotoUrls.removeAt(
        index,
      );

      final remaining =
          photoAnnotations
              .where(
                (item) =>
                    item.photoIndex !=
                    index,
              )
              .map(
                (item) =>
                    item.photoIndex >
                            index
                        ? BreakdownPhotoAnnotation(
                            photoIndex:
                                item.photoIndex -
                                    1,
                            markerX:
                                item.markerX,
                            markerY:
                                item.markerY,
                            note:
                                item.note,
                          )
                        : item,
              )
              .toList();

      photoAnnotations
        ..clear()
        ..addAll(remaining);
    });

    scheduleDraftSave();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> continueToLocation() async {
    FocusScope.of(context)
        .unfocus();

    if (!(formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final draft = buildDraft();

    await RequestDraftStore().save(
      draft,
    );

    if (!mounted) return;

    push(
      context,
      LocationScreen(
        draft: draft,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildProgressHeader(
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
                        .looks_two_outlined,
                    size: 16,
                    color: colors
                        .onPrimaryContainer,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    'STEP 2 OF 4',
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: colors
                          .onPrimaryContainer,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Details',
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
              BorderRadius.circular(
            999,
          ),
          child:
              LinearProgressIndicator(
            value: .50,
            minHeight: 6,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderHero(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: Icon(
              Icons
                  .assignment_outlined,
              color: colors
                  .onPrimaryContainer,
              size: 28,
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
                  'Tell us about the breakdown',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'Accurate vehicle and symptom details help providers prepare a better offer before they arrive.',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    height: 1.45,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueSummary(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const _RaBreakdownSectionHeader(
          icon:
              Icons.car_repair_outlined,
          title:
              'Selected assistance',
          subtitle:
              'Services selected in the previous step.',
        ),
        const SizedBox(
          height: RaSpace.md,
        ),
        Wrap(
          spacing: RaSpace.sm,
          runSpacing: RaSpace.sm,
          children: [
            for (final issue
                in widget.issues)
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      RaSpace.md,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer
                      .withValues(
                    alpha: .55,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                  border: Border.all(
                    color: colors.primary
                        .withValues(
                      alpha: .15,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline_rounded,
                      color:
                          colors.primary,
                      size: 17,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      issue,
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color:
                            colors.primary,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleSection(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final previewPhoto =
        vehiclePhotoUrls.isNotEmpty
            ? vehiclePhotoUrls.first
            : vehicleSnapshot?[
                        'photoData']
                    as String? ??
                '';

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _RaBreakdownSectionHeader(
          icon:
              Icons.directions_car_outlined,
          title:
              'Vehicle information',
          subtitle:
              'Choose a saved vehicle or enter the details manually.',
          action:
              signedIn
                  ? 'Choose saved'
                  : null,
          onAction:
              signedIn
                  ? selectSavedVehicle
                  : null,
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        Container(
          decoration:
              BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          clipBehavior:
              Clip.antiAlias,
          child: Column(
            children: [
              if (modelController
                      .text
                      .trim()
                      .isNotEmpty ||
                  previewPhoto.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets
                          .all(
                    RaSpace.md,
                  ),
                  color: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .35,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 68,
                        clipBehavior:
                            Clip.antiAlias,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          color: colors
                              .surfaceContainerHighest,
                        ),
                        child:
                            VehiclePhotoPreview(
                          model:
                              modelController
                                  .text,
                          photoData:
                              previewPhoto,
                          height: 68,
                          compact: true,
                        ),
                      ),
                      const SizedBox(
                        width:
                            RaSpace.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            if (vehicleId !=
                                null)
                              Container(
                                margin:
                                    const EdgeInsets
                                        .only(
                                  bottom: 5,
                                ),
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      8,
                                  vertical: 3,
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
                                child:
                                    Text(
                                  'SAVED VEHICLE',
                                  style: theme
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: colors
                                        .onPrimaryContainer,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                    letterSpacing:
                                        .6,
                                  ),
                                ),
                              ),
                            Text(
                              modelController
                                      .text
                                      .trim()
                                      .isEmpty
                                  ? 'Vehicle details'
                                  : modelController
                                      .text
                                      .trim(),
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
                              registrationController
                                      .text
                                      .trim()
                                      .isEmpty
                                  ? vehicle
                                  : '${registrationController.text.trim().toUpperCase()} • $vehicle',
                              maxLines: 1,
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

              Padding(
                padding:
                    const EdgeInsets
                        .all(
                  RaSpace.lg,
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          vehicle,
                      key:
                          ValueKey(vehicle),
                      isExpanded: true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Vehicle type',
                        prefixIcon:
                            Icon(
                          Icons
                              .directions_car_outlined,
                        ),
                      ),
                      items: const [
                        'Sedan / Hatchback',
                        'SUV',
                        'Van',
                        'Motorcycle',
                        'Other',
                      ]
                          .map(
                            (type) =>
                                DropdownMenuItem<
                                    String>(
                              value:
                                  type,
                              child:
                                  Text(
                                type,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setState(() {
                          vehicle =
                              value;

                          if (vehicle !=
                              'Other') {
                            customVehicleController
                                .clear();
                          }

                          vehicleSnapshot =
                              null;
                          vehicleId =
                              null;
                        });

                        scheduleDraftSave();
                      },
                    ),

                    if (vehicle ==
                        'Other') ...[
                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),
                      TextFormField(
                        controller:
                            customVehicleController,
                        maxLength: 40,
                        textCapitalization:
                            TextCapitalization
                                .words,
                        textInputAction:
                            TextInputAction
                                .next,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Other vehicle type',
                          hintText:
                              'Three Wheeler, Pickup Truck...',
                          prefixIcon:
                              Icon(
                            Icons
                                .commute_outlined,
                          ),
                        ),
                        validator:
                            (value) {
                          return vehicle ==
                                  'Other'
                              ? validateCustomVehicleType(
                                  value,
                                )
                              : null;
                        },
                        onChanged: (_) {
                          setState(
                            () {},
                          );
                          scheduleDraftSave();
                        },
                      ),
                    ],

                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    TextFormField(
                      controller:
                          modelController,
                      maxLength: 50,
                      textCapitalization:
                          TextCapitalization
                              .words,
                      textInputAction:
                          TextInputAction
                              .next,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Make, model & year',
                        hintText:
                            'Toyota Aqua 2018',
                        prefixIcon:
                            Icon(
                          Icons
                              .badge_outlined,
                        ),
                      ),
                      validator:
                          validateVehicleModelYear,
                      onChanged: (_) {
                        setState(() {
                          vehicleSnapshot =
                              null;
                          vehicleId =
                              null;
                        });

                        scheduleDraftSave();
                      },
                    ),

                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    TextFormField(
                      controller:
                          registrationController,
                      maxLength: 16,
                      textCapitalization:
                          TextCapitalization
                              .characters,
                      textInputAction:
                          TextInputAction
                              .next,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Registration number',
                        hintText:
                            'WP CAB - 1234',
                        prefixIcon:
                            Icon(
                          Icons
                              .pin_outlined,
                        ),
                      ),
                      validator:
                          validateVehicleRegistration,
                      onChanged: (_) {
                        setState(
                          () {},
                        );
                        scheduleDraftSave();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySection(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _RaBreakdownSectionHeader(
          icon:
              Icons.priority_high_rounded,
          title:
              'How urgent is it?',
          subtitle:
              'Choose the option that best describes your current situation.',
        ),
        const SizedBox(
          height: RaSpace.md,
        ),
        _RaBreakdownPrioritySelector(
          selected: priority,
          onSelected: (value) {
            setState(() {
              priority = value;
            });

            scheduleDraftSave();
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _RaBreakdownSectionHeader(
          icon:
              Icons.notes_rounded,
          title:
              'Describe the symptoms',
          subtitle:
              'Tell the provider what you noticed before or when the problem started.',
        ),
        const SizedBox(
          height: RaSpace.md,
        ),
        TextFormField(
          controller:
              descriptionController,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          textCapitalization:
              TextCapitalization.sentences,
          textInputAction:
              TextInputAction.newline,
          validator:
              validateBreakdownDescription,
          onChanged: (_) {
            setState(() {});
            scheduleDraftSave();
          },
          decoration:
              InputDecoration(
            labelText:
                'What happened?',
            hintText:
                'Example: The engine stopped while driving and now makes a clicking sound when I try to start.',
            alignLabelWithHint:
                true,
            prefixIcon: const Padding(
              padding:
                  EdgeInsets.only(
                bottom: 75,
              ),
              child: Icon(
                Icons
                    .description_outlined,
              ),
            ),
            suffixIcon: Padding(
              padding:
                  const EdgeInsets
                      .only(
                bottom: 72,
                right: 4,
              ),
              child:
                  IconButton.filledTonal(
                tooltip:
                    listeningForDescription
                        ? 'Stop voice input'
                        : 'Describe by voice',
                onPressed:
                    toggleDescriptionDictation,
                icon: Icon(
                  listeningForDescription
                      ? Icons
                          .stop_rounded
                      : Icons
                          .mic_none_rounded,
                  color:
                      listeningForDescription
                          ? colors.error
                          : null,
                ),
              ),
            ),
          ),
        ),

        if (listeningForDescription)
          Container(
            margin:
                const EdgeInsets.only(
              top: RaSpace.sm,
            ),
            padding:
                const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration:
                BoxDecoration(
              color: colors
                  .errorContainer
                  .withValues(
                alpha: .35,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mic_rounded,
                  color:
                      colors.error,
                  size: 19,
                ),
                const SizedBox(
                  width: RaSpace.sm,
                ),
                Expanded(
                  child: Text(
                    'Listening… speak naturally and describe the symptoms.',
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPartsSection(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _RaBreakdownSectionHeader(
          icon:
              Icons.settings_outlined,
          title:
              'Parts preference',
          subtitle:
              'This is a preference only. The provider still needs to confirm compatibility, availability, price and warranty.',
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration:
              BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          child:
              DropdownButtonFormField<
                  String>(
            isExpanded: true,
            initialValue:
                partsPreference,
            decoration:
                const InputDecoration(
              labelText:
                  'Replacement parts',
              prefixIcon:
                  Icon(
                Icons
                    .build_circle_outlined,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'discuss',
                child: Text(
                  'Discuss options with provider',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'budget',
                child: Text(
                  'Budget compatible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'branded',
                child: Text(
                  'Branded aftermarket',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'genuine',
                child: Text(
                  'Genuine manufacturer parts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                partsPreference =
                    value ??
                        'discuss';
              });

              scheduleDraftSave();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _RaBreakdownSectionHeader(
          icon:
              Icons.add_a_photo_outlined,
          title:
              'Photo evidence',
          subtitle:
              'Optional, but useful for visible tyre, body, battery or mechanical damage.',
          trailing:
              '${vehiclePhotoUrls.length}/3',
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            RaSpace.lg,
          ),
          decoration:
              BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              20,
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
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              if (vehiclePhotoUrls
                  .isEmpty)
                Container(
                  padding:
                      const EdgeInsets
                          .all(
                    RaSpace.lg,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest
                        .withValues(
                      alpha: .4,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration:
                            BoxDecoration(
                          color: colors
                              .primaryContainer,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .photo_camera_back_outlined,
                          color: colors
                              .onPrimaryContainer,
                          size: 29,
                        ),
                      ),
                      const SizedBox(
                        height:
                            RaSpace.md,
                      ),
                      Text(
                        'Add photos of the problem',
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
                        height: 4,
                      ),
                      Text(
                        'You can add up to 3 photos and mark the exact damaged area.',
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 118,
                  child:
                      ListView.separated(
                    scrollDirection:
                        Axis.horizontal,
                    itemCount:
                        vehiclePhotoUrls
                            .length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      return _RaBreakdownPhotoCard(
                        photoData:
                            vehiclePhotoUrls[
                                index],
                        annotation:
                            _annotationForPhoto(
                          index,
                        ),
                        onTap: () =>
                            annotateVehiclePhoto(
                          index,
                        ),
                        onRemove: () =>
                            removeVehiclePhoto(
                          index,
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(
                height: RaSpace.md,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      uploadingVehiclePhoto ||
                              vehiclePhotoUrls
                                      .length >=
                                  3
                          ? null
                          : addVehiclePhotos,
                  icon:
                      uploadingVehiclePhoto
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
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
                  label: Text(
                    uploadingVehiclePhoto
                        ? 'Preparing photo…'
                        : vehiclePhotoUrls
                                    .length >=
                                3
                            ? 'Maximum 3 photos added'
                            : 'Add Photo',
                  ),
                ),
              ),

              if (vehiclePhotoUrls
                  .isNotEmpty) ...[
                const SizedBox(
                  height: RaSpace.sm,
                ),
                Row(
                  children: [
                    Icon(
                      Icons
                          .edit_location_alt_outlined,
                      size: 17,
                      color:
                          colors.primary,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Expanded(
                      child: Text(
                        'Tap any photo to mark the damaged area and add a note.',
                        style: theme
                            .textTheme
                            .bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _RaBreakdownSectionHeader(
          icon:
              Icons.sticky_note_2_outlined,
          title:
              'Additional notes',
          subtitle:
              'Optional information that may help the provider prepare.',
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        TextFormField(
          controller:
              notesController,
          maxLines: 3,
          maxLength: 300,
          textCapitalization:
              TextCapitalization.sentences,
          decoration:
              const InputDecoration(
            labelText:
                'Additional notes',
            hintText:
                'Example: Vehicle is parked inside a basement car park.',
            alignLabelWithHint:
                true,
            prefixIcon: Padding(
              padding:
                  EdgeInsets.only(
                bottom: 45,
              ),
              child: Icon(
                Icons
                    .notes_outlined,
              ),
            ),
          ),
          onChanged: (_) {
            setState(() {});
            scheduleDraftSave();
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

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
              alpha: .65,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: .035,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              -5,
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip:
                  'Save draft',
              onPressed: () =>
                  saveDraft(),
              icon: const Icon(
                Icons
                    .bookmark_add_outlined,
              ),
            ),

            const SizedBox(
              width: RaSpace.sm,
            ),

            Expanded(
              child:
                  FilledButton.icon(
                onPressed:
                    continueToLocation,
                icon: const Icon(
                  Icons
                      .arrow_forward_rounded,
                ),
                label: const Text(
                  'Continue to Location',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title:
            const Text(
          'Request Details',
        ),
        actions: [
          IconButton(
            tooltip: 'Save draft',
            onPressed: () =>
                saveDraft(),
            icon: const Icon(
              Icons
                  .bookmark_border_rounded,
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
              child: Form(
                key: formKey,
                autovalidateMode:
                    AutovalidateMode
                        .onUserInteraction,
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
                    _buildProgressHeader(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    _buildHeaderHero(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildIssueSummary(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildVehicleSection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildPrioritySection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildDescriptionSection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildPartsSection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildPhotoSection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xxl,
                    ),

                    _buildNotesSection(
                      context,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.xl,
                    ),

                    const SafetyBox(),
                  ],
                ),
              ),
            ),

            _buildBottomBar(
              context,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// UI HELPERS
// =============================================================================

class _RaBreakdownSectionHeader
    extends StatelessWidget {
  const _RaBreakdownSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final String? action;
  final VoidCallback? onAction;

  final String? trailing;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: colors
                .primaryContainer,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),

                  if (trailing !=
                      null)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                      child: Text(
                        trailing!,
                        style: theme
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),

                  if (action !=
                          null &&
                      onAction !=
                          null)
                    TextButton(
                      onPressed:
                          onAction,
                      child:
                          Text(action!),
                    ),
                ],
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                subtitle,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaBreakdownPrioritySelector
    extends StatelessWidget {
  const _RaBreakdownPrioritySelector({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String>
      onSelected;

  static const items = [
    (
      'normal',
      'Normal',
      'Safe location, no immediate danger',
      Icons.schedule_rounded,
    ),
    (
      'urgent',
      'Urgent',
      'Need assistance as soon as possible',
      Icons.speed_rounded,
    ),
    (
      'road_blocking',
      'Blocking road',
      'Vehicle is obstructing traffic',
      Icons.traffic_rounded,
    ),
    (
      'safety_risk',
      'Safety risk',
      'Driver or passengers may be unsafe',
      Icons.warning_amber_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            (constraints.maxWidth -
                    RaSpace.sm) /
                2;

        return Wrap(
          spacing: RaSpace.sm,
          runSpacing: RaSpace.sm,
          children: [
            for (final item
                in items)
              SizedBox(
                width: width,
                child: Material(
                  color: selected ==
                          item.$1
                      ? colors
                          .primaryContainer
                          .withValues(
                          alpha: .55,
                        )
                      : colors.surface,
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        onSelected(
                      item.$1,
                    ),
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minHeight: 145,
                      ),
                      padding:
                          const EdgeInsets
                              .all(
                        RaSpace.md,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                        border:
                            Border.all(
                          color: selected ==
                                  item.$1
                              ? colors
                                  .primary
                                  .withValues(
                                  alpha:
                                      .5,
                                )
                              : colors
                                  .outlineVariant
                                  .withValues(
                                  alpha:
                                      .6,
                                ),
                          width: selected ==
                                  item.$1
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    BoxDecoration(
                                  color: selected ==
                                          item.$1
                                      ? colors
                                          .primary
                                      : colors
                                          .surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                                child:
                                    Icon(
                                  item.$4,
                                  color: selected ==
                                          item.$1
                                      ? colors
                                          .onPrimary
                                      : colors
                                          .primary,
                                  size:
                                      20,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                selected ==
                                        item.$1
                                    ? Icons
                                        .check_circle_rounded
                                    : Icons
                                        .radio_button_unchecked_rounded,
                                color: selected ==
                                        item.$1
                                    ? colors
                                        .primary
                                    : colors
                                        .outline,
                                size: 21,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height:
                                RaSpace.md,
                          ),
                          Text(
                            item.$2,
                            style: theme
                                .textTheme
                                .labelLarge
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
                            item.$3,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              height:
                                  1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RaBreakdownPhotoSource
    extends StatelessWidget {
  const _RaBreakdownPhotoSource({
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
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
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
                      title,
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
              Icon(
                Icons
                    .chevron_right_rounded,
                color: colors
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaBreakdownPhotoCard
    extends StatelessWidget {
  const _RaBreakdownPhotoCard({
    required this.photoData,
    required this.annotation,
    required this.onTap,
    required this.onRemove,
  });

  final String photoData;

  final BreakdownPhotoAnnotation?
      annotation;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    Widget photo;

    try {
      photo = Image.memory(
        base64Decode(photoData),
        width: 118,
        height: 118,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return Container(
            color: colors
                .surfaceContainerHighest,
            alignment:
                Alignment.center,
            child: const Icon(
              Icons
                  .broken_image_outlined,
            ),
          );
        },
      );
    } on FormatException {
      photo = Container(
        color: colors
            .surfaceContainerHighest,
        alignment:
            Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 118,
        height: 118,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                child: photo,
              ),
            ),

            if (annotation != null)
              Positioned(
                left: annotation!
                            .markerX *
                        102 -
                    3,
                top: annotation!
                            .markerY *
                        92 -
                    7,
                child: Icon(
                  Icons
                      .location_on_rounded,
                  color:
                      colors.error,
                  size: 25,
                  shadows: const [
                    Shadow(
                      color:
                          Colors.white,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),

            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: .60,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    999,
                  ),
                ),
                child: const Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .edit_location_alt_outlined,
                      size: 13,
                      color:
                          Colors.white,
                    ),
                    SizedBox(
                      width: 3,
                    ),
                    Text(
                      'Mark',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 4,
              right: 4,
              child:
                  IconButton.filled(
                tooltip:
                    'Remove photo',
                visualDensity:
                    VisualDensity
                        .compact,
                style: IconButton
                    .styleFrom(
                  backgroundColor:
                      Colors.black
                          .withValues(
                    alpha: .60,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                onPressed:
                    onRemove,
                icon: const Icon(
                  Icons
                      .close_rounded,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}