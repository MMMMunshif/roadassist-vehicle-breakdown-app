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

class _BreakdownDetailsScreenState
    extends State<BreakdownDetailsScreen> {
  final formKey = GlobalKey<FormState>();

  final modelController = TextEditingController();
  final registrationController = TextEditingController();
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();
  final customVehicleController = TextEditingController();

  final SpeechToText speechToText = SpeechToText();

  String vehicle = 'Sedan / Hatchback';
  String? vehicleId;

  Map<String, dynamic>? vehicleSnapshot;

  String priority = 'normal';
  String partsPreference = 'discuss';

  bool uploadingVehiclePhoto = false;
  bool listeningForDescription = false;

  Timer? draftSaveDebounce;

  final List<String> vehiclePhotoUrls = [];

  final List<BreakdownPhotoAnnotation>
      photoAnnotations = [];

  static const Set<String> standardVehicleTypes = {
    'Sedan / Hatchback',
    'SUV',
    'Van',
    'Motorcycle',
  };

  @override
  void initState() {
    super.initState();

    final draft = widget.initialDraft;

    if (draft == null) {
      if (signedIn) {
        unawaited(loadDefaultVehicle());
      }

      return;
    }

    vehicleId = draft.vehicleId;
    vehicleSnapshot = draft.vehicleSnapshot;

    if (standardVehicleTypes.contains(
      draft.vehicleType,
    )) {
      vehicle = draft.vehicleType;
    } else {
      vehicle = 'Other';
      customVehicleController.text =
          draft.vehicleType;
    }

    modelController.text = draft.modelYear;

    registrationController.text =
        draft.registration;

    descriptionController.text =
        draft.description;

    notesController.text = draft.notes;

    priority = draft.priority;

    partsPreference =
        draft.partsPreference;

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

    unawaited(
      speechToText.stop(),
    );

    modelController.dispose();
    registrationController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    customVehicleController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // VEHICLE
  // ===========================================================================

  Future<void> loadDefaultVehicle() async {
    try {
      final selected =
          await VehicleService().loadDefault();

      if (!mounted ||
          selected == null ||
          modelController.text.trim().isNotEmpty ||
          registrationController.text
              .trim()
              .isNotEmpty) {
        return;
      }

      applyVehicle(selected);
    } catch (_) {
      // Manual vehicle entry remains available.
    }
  }

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

      vehicleSnapshot =
          selected.toJson();

      if (standardVehicleTypes.contains(
        selected.vehicleType,
      )) {
        vehicle = selected.vehicleType;

        customVehicleController.clear();
      } else {
        vehicle = 'Other';

        customVehicleController.text =
            selected.vehicleType;
      }

      modelController.text =
          selected.label;

      registrationController.text =
          selected.registration;
    });
  }

  // ===========================================================================
  // DRAFT
  // ===========================================================================

  RequestDraft buildDraft() {
    final actualVehicleType =
        vehicle == 'Other'
            ? customVehicleController.text
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
                    registrationController.text,
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
          descriptionController.text.trim(),
      notes: notesController.text.trim(),
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
          widget.initialDraft?.latitude ??
              6.9271,
      longitude:
          widget.initialDraft?.longitude ??
              79.8612,
      provider:
          widget.initialDraft?.provider ??
              '',
      preferredProviderId:
          widget.initialDraft
                  ?.preferredProviderId ??
              '',
      vehiclePhotoUrls:
          List<String>.unmodifiable(
        vehiclePhotoUrls,
      ),
      photoAnnotations:
          List<BreakdownPhotoAnnotation>.unmodifiable(
        photoAnnotations,
      ),
    );
  }

  Future<void> saveDraft({
    bool showConfirmation = true,
  }) async {
    try {
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
    } catch (error) {
      if (!mounted ||
          !showConfirmation) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not save draft: $error',
          ),
        ),
      );
    }
  }

  void scheduleDraftSave() {
    draftSaveDebounce?.cancel();

    draftSaveDebounce = Timer(
      const Duration(
        milliseconds: 600,
      ),
      () {
        unawaited(
          saveDraft(
            showConfirmation: false,
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SPEECH
  // ===========================================================================

  Future<void>
      toggleDescriptionDictation() async {
    if (listeningForDescription) {
      await speechToText.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        listeningForDescription = false;
      });

      scheduleDraftSave();

      return;
    }

    final available =
        await speechToText.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }

        if (status == 'done' ||
            status == 'notListening') {
          setState(() {
            listeningForDescription =
                false;
          });

          scheduleDraftSave();
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          listeningForDescription =
              false;
        });
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

  // ===========================================================================
  // PHOTOS
  // ===========================================================================

  Future<ImageSource?>
      choosePhotoSource() {
    return showModalBottomSheet<
        ImageSource>(
      context: context,
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

        final remaining =
            3 - vehiclePhotoUrls.length;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0D1D2B,
                  )
                : colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(
                      alpha: .24,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                'Add breakdown photos',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      colors.onSurface,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                '$remaining of 3 photo slots remaining',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 16,
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
                height: 8,
              ),

              _RaBreakdownPhotoSource(
                icon: Icons
                    .camera_alt_outlined,
                title: 'Take a photo',
                subtitle:
                    'Capture the problem using your camera',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> addVehiclePhotos() async {
    if (uploadingVehiclePhoto ||
        vehiclePhotoUrls.length >= 3) {
      return;
    }

    final source =
        await choosePhotoSource();

    if (source == null || !mounted) {
      return;
    }

    final remainingSlots =
        3 - vehiclePhotoUrls.length;

    setState(() {
      uploadingVehiclePhoto = true;
    });

    try {
      final picker = ImagePicker();

      final List<XFile> selectedPhotos;

      if (source ==
          ImageSource.gallery) {
        selectedPhotos =
            await picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1600,
          limit: remainingSlots,
        );
      } else {
        final captured =
            await Navigator.of(context)
                .push<XFile>(
          MaterialPageRoute(
            builder: (_) =>
                const CameraCaptureScreen(),
          ),
        );

        selectedPhotos = captured == null
            ? <XFile>[]
            : <XFile>[
                captured,
              ];
      }

      if (selectedPhotos.isEmpty) {
        return;
      }

      final prepared = <String>[];

      for (final photo
          in selectedPhotos) {
        if (prepared.length >=
            remainingSlots) {
          break;
        }

        final encoded =
            await PhotoUploadService()
                .prepareVehiclePhoto(
          photo,
        );

        if (vehiclePhotoUrls.contains(
              encoded,
            ) ||
            prepared.contains(
              encoded,
            )) {
          continue;
        }

        prepared.add(encoded);
      }

      if (!mounted ||
          prepared.isEmpty) {
        return;
      }

      setState(() {
        vehiclePhotoUrls.addAll(
          prepared,
        );
      });

      await saveDraft(
        showConfirmation: false,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            prepared.length == 1
                ? 'Breakdown photo added.'
                : '${prepared.length} breakdown photos added.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Photo upload failed: $error',
          ),
        ),
      );
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
      annotationForPhoto(
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

  Future<void> annotatePhoto(
    int index,
  ) async {
    if (index < 0 ||
        index >= vehiclePhotoUrls.length) {
      return;
    }

    final existing =
        annotationForPhoto(index);

    double markerX =
        existing?.markerX ?? .5;

    double markerY =
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
            final colors =
                Theme.of(context)
                    .colorScheme;

            Widget image;

            try {
              image = Image.memory(
                base64Decode(
                  vehiclePhotoUrls[index],
                ),
                fit: BoxFit.cover,
              );
            } on FormatException {
              image = Container(
                color: colors
                    .surfaceContainerHighest,
                alignment:
                    Alignment.center,
                child: const Icon(
                  Icons
                      .broken_image_outlined,
                ),
              );
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.all(
                16,
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 520,
                ),
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Text(
                        'Mark the damaged area',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Tap directly on the area you want the provider to notice.',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 9.5,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(
                        height: 15,
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
                                        )
                                        .toDouble();

                                    markerY = (details
                                                .localPosition
                                                .dy /
                                            constraints
                                                .maxHeight)
                                        .clamp(
                                          0.0,
                                          1.0,
                                        )
                                        .toDouble();
                                  },
                                );
                              },
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  17,
                                ),
                                child: Stack(
                                  fit:
                                      StackFit
                                          .expand,
                                  children: [
                                    image,

                                    Positioned(
                                      left: markerX *
                                              constraints
                                                  .maxWidth -
                                          15,
                                      top: markerY *
                                              constraints
                                                  .maxHeight -
                                          28,
                                      child: Icon(
                                        Icons
                                            .location_on_rounded,
                                        color: colors
                                            .error,
                                        size: 31,
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
                        height: 13,
                      ),

                      TextField(
                        controller:
                            noteController,
                        maxLength: 120,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization:
                            TextCapitalization
                                .sentences,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Damage note',
                          hintText:
                              'e.g. Deep cut on rear-left tyre',
                          alignLabelWithHint:
                              true,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton(
                              onPressed: () {
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
                            width: 8,
                          ),

                          Expanded(
                            flex: 2,
                            child:
                                FilledButton.icon(
                              onPressed: () {
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
                              icon: const Icon(
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
    if (index < 0 ||
        index >= vehiclePhotoUrls.length) {
      return;
    }

    setState(() {
      vehiclePhotoUrls.removeAt(
        index,
      );

      final remainingAnnotations =
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
        ..addAll(
          remainingAnnotations,
        );
    });

    scheduleDraftSave();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  Future<void>
      continueToLocation() async {
    FocusScope.of(context).unfocus();

    final valid =
        formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    final draft = buildDraft();

    await RequestDraftStore().save(
      draft,
    );

    if (!mounted) {
      return;
    }

    push(
      context,
      LocationScreen(
        draft: draft,
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors =
        theme.colorScheme;

    final previewPhoto =
        vehiclePhotoUrls.isNotEmpty
            ? vehiclePhotoUrls.first
            : (vehicleSnapshot?[
                        'photoData']
                    as String? ??
                '');

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Request Details',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Save draft',
            onPressed: () {
              unawaited(
                saveDraft(),
              );
            },
            icon: const Icon(
              Icons
                  .bookmark_border_rounded,
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
              child: Form(
                key: formKey,
                autovalidateMode:
                    AutovalidateMode
                        .onUserInteraction,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior
                          .onDrag,
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
                    const _RaBreakdownProgress(),

                    const SizedBox(
                      height: 16,
                    ),

                    _RaBreakdownHero(
                      issues:
                          widget.issues,
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    _RaBreakdownSectionHeading(
                      icon: Icons
                          .directions_car_outlined,
                      title:
                          'Vehicle information',
                      subtitle:
                          'Choose a saved vehicle or enter the details manually.',
                      action: signedIn
                          ? 'Choose saved'
                          : null,
                      onAction: signedIn
                          ? selectSavedVehicle
                          : null,
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaBreakdownSurface(
                      child:
                          _buildVehicleSection(
                        context,
                        previewPhoto,
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    const _RaBreakdownSectionHeading(
                      icon: Icons
                          .priority_high_rounded,
                      title:
                          'How urgent is it?',
                      subtitle:
                          'Choose the option that best describes your current situation.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaBreakdownPriorityGrid(
                      selected: priority,
                      onSelected:
                          (value) {
                        setState(() {
                          priority = value;
                        });

                        scheduleDraftSave();
                      },
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    const _RaBreakdownSectionHeading(
                      icon:
                          Icons.notes_rounded,
                      title:
                          'Describe the symptoms',
                      subtitle:
                          'Tell the provider what happened and what you noticed.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _buildDescriptionField(
                      context,
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    const _RaBreakdownSectionHeading(
                      icon:
                          Icons.settings_outlined,
                      title:
                          'Parts preference',
                      subtitle:
                          'The provider confirms compatibility, price, availability and warranty.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaBreakdownSurface(
                      child:
                          _buildPartsPreference(),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    _RaBreakdownSectionHeading(
                      icon: Icons
                          .add_a_photo_outlined,
                      title:
                          'Photo evidence',
                      subtitle:
                          'Optional. Add visible damage and mark the exact area.',
                      trailing:
                          '${vehiclePhotoUrls.length}/3',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaBreakdownSurface(
                      child:
                          _buildPhotoSection(
                        context,
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    const _RaBreakdownSectionHeading(
                      icon: Icons
                          .sticky_note_2_outlined,
                      title:
                          'Additional notes',
                      subtitle:
                          'Optional information that may help the provider prepare.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    TextFormField(
                      controller:
                          notesController,
                      maxLines: 3,
                      maxLength: 300,
                      textCapitalization:
                          TextCapitalization
                              .sentences,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Anything else?',
                        hintText:
                            'Parking access, special vehicle details, tools required...',
                        alignLabelWithHint:
                            true,
                      ),
                      onChanged: (_) {
                        scheduleDraftSave();
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    _buildSafetyNotice(
                      context,
                    ),
                  ],
                ),
              ),
            ),

            _buildBottomActionBar(
              context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSection(
    BuildContext context,
    String previewPhoto,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        if (modelController.text
                .trim()
                .isNotEmpty ||
            previewPhoto.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 82,
                height: 62,
                clipBehavior:
                    Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    VehiclePhotoPreview(
                  model:
                      modelController.text,
                  photoData:
                      previewPhoto,
                  height: 62,
                  compact: true,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (vehicleId != null)
                      Text(
                        'SAVED VEHICLE',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 7.5,
                          letterSpacing: .8,
                          color: colors
                              .primary,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                    if (vehicleId != null)
                      const SizedBox(
                        height: 3,
                      ),

                    Text(
                      modelController.text
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
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight
                                .w700,
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
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.5,
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
            height: 16,
          ),
        ],

        DropdownButtonFormField<String>(
          initialValue: vehicle,
          key: ValueKey(vehicle),
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText:
                'Vehicle type',
            prefixIcon: Icon(
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
                (value) =>
                    DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              vehicle = value;

              if (vehicle != 'Other') {
                customVehicleController
                    .clear();
              }

              vehicleId = null;
              vehicleSnapshot = null;
            });

            scheduleDraftSave();
          },
        ),

        if (vehicle == 'Other') ...[
          const SizedBox(
            height: 11,
          ),

          TextFormField(
            controller:
                customVehicleController,
            maxLength: 40,
            textCapitalization:
                TextCapitalization.words,
            textInputAction:
                TextInputAction.next,
            decoration:
                const InputDecoration(
              labelText:
                  'Other vehicle type',
              hintText:
                  'Three Wheeler, Pickup Truck...',
              prefixIcon: Icon(
                Icons.commute_outlined,
              ),
            ),
            validator:
                validateCustomVehicleType,
            onChanged: (_) {
              scheduleDraftSave();
            },
          ),
        ],

        const SizedBox(
          height: 11,
        ),

        TextFormField(
          controller:
              modelController,
          maxLength: 50,
          textCapitalization:
              TextCapitalization.words,
          textInputAction:
              TextInputAction.next,
          decoration:
              const InputDecoration(
            labelText:
                'Make, model & year',
            hintText:
                'Toyota Aqua 2018',
            prefixIcon: Icon(
              Icons.badge_outlined,
            ),
          ),
          validator:
              validateVehicleModelYear,
          onChanged: (_) {
            setState(() {
              vehicleId = null;
              vehicleSnapshot = null;
            });

            scheduleDraftSave();
          },
        ),

        const SizedBox(
          height: 11,
        ),

        TextFormField(
          controller:
              registrationController,
          maxLength: 16,
          textCapitalization:
              TextCapitalization
                  .characters,
          textInputAction:
              TextInputAction.next,
          decoration:
              const InputDecoration(
            labelText:
                'Registration number',
            hintText:
                'WP CAB-1234',
            prefixIcon: Icon(
              Icons.pin_outlined,
            ),
          ),
          validator:
              validateVehicleRegistration,
          onChanged: (_) {
            scheduleDraftSave();
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller:
              descriptionController,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          textCapitalization:
              TextCapitalization
                  .sentences,
          validator:
              validateBreakdownDescription,
          onChanged: (_) {
            scheduleDraftSave();
          },
          decoration:
              InputDecoration(
            labelText:
                'What happened?',
            hintText:
                'Example: Engine stopped while driving and now makes a clicking sound.',
            alignLabelWithHint:
                true,
            suffixIcon: Padding(
              padding:
                  const EdgeInsets.only(
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

        if (listeningForDescription) ...[
          const SizedBox(
            height: 8,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration: BoxDecoration(
              color: colors.error
                  .withValues(
                alpha: .07,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mic_rounded,
                  color: colors.error,
                  size: 18,
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: Text(
                    'Listening… describe the symptoms naturally.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPartsPreference() {
    return DropdownButtonFormField<String>(
      initialValue:
          partsPreference,
      decoration:
          const InputDecoration(
        labelText:
            'Replacement parts',
        prefixIcon: Icon(
          Icons
              .build_circle_outlined,
        ),
      ),
      items: const [
        DropdownMenuItem<String>(
          value: 'discuss',
          child: Text(
            'Discuss options with provider',
          ),
        ),
        DropdownMenuItem<String>(
          value: 'budget',
          child: Text(
            'Budget compatible',
          ),
        ),
        DropdownMenuItem<String>(
          value: 'branded',
          child: Text(
            'Branded aftermarket',
          ),
        ),
        DropdownMenuItem<String>(
          value: 'genuine',
          child: Text(
            'Genuine manufacturer parts',
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          partsPreference = value;
        });

        scheduleDraftSave();
      },
    );
  }

  Widget _buildPhotoSection(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (vehiclePhotoUrls.isEmpty)
          Container(
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(
                alpha: .32,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 57,
                  height: 57,
                  decoration:
                      BoxDecoration(
                    color: colors.primary
                        .withValues(
                      alpha: .08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .photo_camera_back_outlined,
                    color: colors.primary,
                    size: 27,
                  ),
                ),

                const SizedBox(
                  height: 11,
                ),

                Text(
                  'Add photos of the problem',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Up to 3 photos. Tap a photo after adding it to mark the damaged area.',
                  textAlign:
                      TextAlign.center,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9,
                    height: 1.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  vehiclePhotoUrls.length,
              separatorBuilder:
                  (context, index) {
                return const SizedBox(
                  width: 8,
                );
              },
              itemBuilder:
                  (context, index) {
                return _RaBreakdownPhotoCard(
                  data:
                      vehiclePhotoUrls[index],
                  annotation:
                      annotationForPhoto(
                    index,
                  ),
                  onTap: () {
                    unawaited(
                      annotatePhoto(
                        index,
                      ),
                    );
                  },
                  onRemove: () {
                    removeVehiclePhoto(
                      index,
                    );
                  },
                );
              },
            ),
          ),

        const SizedBox(
          height: 12,
        ),

        OutlinedButton.icon(
          onPressed:
              uploadingVehiclePhoto ||
                      vehiclePhotoUrls
                              .length >=
                          3
                  ? null
                  : addVehiclePhotos,
          icon: uploadingVehiclePhoto
              ? const SizedBox.square(
                  dimension: 17,
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
            uploadingVehiclePhoto
                ? 'Preparing Photos…'
                : vehiclePhotoUrls.length >=
                        3
                    ? 'Maximum 3 Photos Added'
                    : 'Add Photo',
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyNotice(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration: BoxDecoration(
        color: raGold.withValues(
          alpha: .075,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: raGold.withValues(
            alpha: .14,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons
                .health_and_safety_outlined,
            size: 19,
            color: raGold,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              'Do not inspect or photograph the vehicle from an unsafe traffic position. Move to safety first whenever possible.',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 9.5,
                height: 1.45,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

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
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Save draft',
              onPressed: () {
                unawaited(
                  saveDraft(),
                );
              },
              icon: const Icon(
                Icons
                    .bookmark_add_outlined,
              ),
            ),

            const SizedBox(
              width: 8,
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
}

// =============================================================================
// PROGRESS
// =============================================================================

class _RaBreakdownProgress
    extends StatelessWidget {
  const _RaBreakdownProgress();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.primary
                    .withValues(
                  alpha: .08,
                ),
                borderRadius:
                    BorderRadius.circular(
                  999,
                ),
              ),
              child: Text(
                'STEP 2 OF 4',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: colors.primary,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Details',
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: colors.primary,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 7,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            999,
          ),
          child:
              LinearProgressIndicator(
            value: .50,
            minHeight: 5,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HERO
// =============================================================================

class _RaBreakdownHero
    extends StatelessWidget {
  const _RaBreakdownHero({
    required this.issues,
  });

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B477D),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -31,
            child: Icon(
              Icons
                  .engineering_outlined,
              size: 125,
              color: Colors.white
                  .withValues(
                alpha: .055,
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us about the vehicle',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                'These details help providers understand the problem before they send an offer.',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white
                      .withValues(
                    alpha: .80,
                  ),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 13,
              ),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final issue
                      in issues)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: .13,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons
                                .check_circle_outline_rounded,
                            color:
                                Colors.white,
                            size: 13,
                          ),

                          const SizedBox(
                            width: 4,
                          ),

                          Text(
                            issue,
                            style: GoogleFonts
                                .plusJakartaSans(
                              color:
                                  Colors.white,
                              fontSize: 8.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADING
// =============================================================================

class _RaBreakdownSectionHeading
    extends StatelessWidget {
  const _RaBreakdownSectionHeading({
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
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: colors.primary
                .withValues(
              alpha: .08,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color: colors.primary,
            size: 19,
          ),
        ),

        const SizedBox(
          width: 10,
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
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ),

                  if (trailing != null)
                    Text(
                      trailing!,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            colors.primary,
                      ),
                    ),

                  if (action != null &&
                      onAction != null)
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
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 9.3,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SURFACE
// =============================================================================

class _RaBreakdownSurface
    extends StatelessWidget {
  const _RaBreakdownSurface({
    required this.child,
  });

  final Widget child;

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
      child: child,
    );
  }
}

// =============================================================================
// PRIORITY
// =============================================================================

class _RaBreakdownPriorityGrid
    extends StatelessWidget {
  const _RaBreakdownPriorityGrid({
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
      'Safe location',
      Icons.schedule_rounded,
    ),
    (
      'urgent',
      'Urgent',
      'Need help soon',
      Icons.speed_rounded,
    ),
    (
      'road_blocking',
      'Blocking road',
      'Obstructing traffic',
      Icons.traffic_rounded,
    ),
    (
      'safety_risk',
      'Safety risk',
      'People may be unsafe',
      Icons.warning_amber_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final cardWidth =
            (constraints.maxWidth -
                    8) /
                2;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: Material(
                  color: selected ==
                          item.$1
                      ? colors.primary
                          .withValues(
                          alpha: .07,
                        )
                      : colors.surface,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      onSelected(
                        item.$1,
                      );
                    },
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minHeight: 122,
                      ),
                      padding:
                          const EdgeInsets
                              .all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        border:
                            Border.all(
                          color: selected ==
                                  item.$1
                              ? colors
                                  .primary
                                  .withValues(
                                  alpha:
                                      .42,
                                )
                              : colors
                                  .outlineVariant
                                  .withValues(
                                  alpha:
                                      .43,
                                ),
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
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
                                width: 36,
                                height: 36,
                                decoration:
                                    BoxDecoration(
                                  color: selected ==
                                          item.$1
                                      ? colors
                                          .primary
                                      : colors
                                          .primary
                                          .withValues(
                                          alpha:
                                              .08,
                                        ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    11,
                                  ),
                                ),
                                child: Icon(
                                  item.$4,
                                  size: 18,
                                  color: selected ==
                                          item.$1
                                      ? colors
                                          .onPrimary
                                      : colors
                                          .primary,
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
                                size: 19,
                                color: selected ==
                                        item.$1
                                    ? colors
                                        .primary
                                    : colors
                                        .outline,
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            item.$2,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            item.$3,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 8.5,
                              color: colors
                                  .onSurfaceVariant,
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

// =============================================================================
// PHOTO SOURCE
// =============================================================================

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
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors
          .surfaceContainerHighest
          .withValues(
        alpha: .34,
      ),
      borderRadius:
          BorderRadius.circular(
        17,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            13,
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      colors.primary,
                  size: 19,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10.8,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.7,
                        color: colors
                            .onSurfaceVariant,
                      ),
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

// =============================================================================
// PHOTO CARD
// =============================================================================

class _RaBreakdownPhotoCard
    extends StatelessWidget {
  const _RaBreakdownPhotoCard({
    required this.data,
    required this.annotation,
    required this.onTap,
    required this.onRemove,
  });

  final String data;

  final BreakdownPhotoAnnotation?
      annotation;

  final VoidCallback onTap;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    Widget preview;

    try {
      preview = Image.memory(
        base64Decode(data),
        width: 116,
        height: 116,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
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
      preview = Container(
        color: colors
            .surfaceContainerHighest,
        alignment:
            Alignment.center,
        child: const Icon(
          Icons
              .broken_image_outlined,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 116,
        height: 116,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                child: preview,
              ),
            ),

            if (annotation != null)
              Positioned(
                left: (annotation!
                            .markerX *
                        100)
                    .clamp(
                      0.0,
                      91.0,
                    )
                    .toDouble(),
                top: (annotation!
                            .markerY *
                        88)
                    .clamp(
                      0.0,
                      80.0,
                    )
                    .toDouble(),
                child: Icon(
                  Icons
                      .location_on_rounded,
                  color: colors.error,
                  size: 24,
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
                  vertical: 4,
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
                      size: 12,
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
                        fontSize: 8.5,
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
                tooltip: 'Remove',
                visualDensity:
                    VisualDensity.compact,
                iconSize: 14,
                style:
                    IconButton.styleFrom(
                  minimumSize:
                      const Size(
                    30,
                    30,
                  ),
                  backgroundColor:
                      Colors.black
                          .withValues(
                    alpha: .62,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}