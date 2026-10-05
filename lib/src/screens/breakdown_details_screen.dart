part of '../screens.dart';

class BreakdownDetailsScreen extends StatefulWidget {
  const BreakdownDetailsScreen({
    super.key,
    required this.issues,
    this.initialDraft,
  });
  final List<String> issues;
  final RequestDraft? initialDraft;
  @override
  State<BreakdownDetailsScreen> createState() => _BreakdownDetailsScreenState();
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

  Future<void> selectSavedVehicle() async {
    final selected = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => const VehiclesScreen(selecting: true)),
    );
    if (selected == null || !mounted) return;
    applyVehicle(selected);
  }

  void applyVehicle(Vehicle selected) {
    setState(() {
      vehicleId = selected.id;
      vehicleSnapshot = selected.toJson();
      vehicle = selected.vehicleType;
      if (vehicle == 'Other') customVehicleController.text = 'Other';
      modelController.text = selected.label;
      registrationController.text = selected.registration;
    });
  }

  Future<void> loadDefaultVehicle() async {
    try {
      final selected = await VehicleService().loadDefault();
      if (selected != null &&
          mounted &&
          modelController.text.isEmpty &&
          registrationController.text.isEmpty) {
        applyVehicle(selected);
      }
    } catch (_) {
      // Vehicle lookup is optional; manual entry stays available offline.
    }
  }

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
      if (signedIn) loadDefaultVehicle();
      return;
    }
    vehicleId = draft.vehicleId;
    vehicleSnapshot = draft.vehicleSnapshot;
    const standardTypes = {'Sedan / Hatchback', 'SUV', 'Van', 'Motorcycle'};
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
    vehiclePhotoUrls.addAll(draft.vehiclePhotoUrls);
    photoAnnotations.addAll(draft.photoAnnotations);
  }

  RequestDraft buildDraft() => RequestDraft(
    vehicleId: vehicleId,
    vehicleSnapshot: vehicleSnapshot == null
        ? null
        : {
            ...vehicleSnapshot!,
            'vehicleType': vehicle == 'Other'
                ? customVehicleController.text.trim()
                : vehicle,
            'modelYear': modelController.text.trim(),
            'registration': normalizeVehicleRegistration(
              registrationController.text,
            ),
          },
    issues: widget.issues,
    vehicleType: vehicle == 'Other'
        ? customVehicleController.text.trim()
        : vehicle,
    modelYear: modelController.text.trim(),
    registration: normalizeVehicleRegistration(registrationController.text),
    description: descriptionController.text.trim(),
    notes: notesController.text.trim(),
    priority: priority,
    partsPreference: partsPreference,
    location:
        widget.initialDraft?.location ??
        'Select current GPS or enter location manually',
    landmark: widget.initialDraft?.landmark ?? '',
    locationAccuracyMeters: widget.initialDraft?.locationAccuracyMeters,
    latitude: widget.initialDraft?.latitude ?? 6.9271,
    longitude: widget.initialDraft?.longitude ?? 79.8612,
    provider: widget.initialDraft?.provider ?? '',
    preferredProviderId: widget.initialDraft?.preferredProviderId ?? '',
    vehiclePhotoUrls: List.unmodifiable(vehiclePhotoUrls),
    photoAnnotations: List.unmodifiable(photoAnnotations),
  );

  Future<void> saveDraft({bool showConfirmation = true}) async {
    await RequestDraftStore().save(buildDraft());
    if (!mounted || !showConfirmation) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request saved as a draft.')));
  }

  void scheduleDraftSave() {
    draftSaveDebounce?.cancel();
    draftSaveDebounce = Timer(
      const Duration(milliseconds: 600),
      () => RequestDraftStore().save(buildDraft()),
    );
  }

  Future<void> toggleDescriptionDictation() async {
    if (listeningForDescription) {
      await speechToText.stop();
      if (mounted) setState(() => listeningForDescription = false);
      scheduleDraftSave();
      return;
    }
    final available = await speechToText.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => listeningForDescription = false);
          scheduleDraftSave();
        }
      },
      onError: (_) {
        if (mounted) setState(() => listeningForDescription = false);
      },
    );
    if (!available || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable. Check microphone permission.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => listeningForDescription = true);
    await speechToText.listen(
      onResult: (result) {
        if (!mounted || result.recognizedWords.trim().isEmpty) return;
        setState(() => descriptionController.text = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> addVehiclePhotos() async {
    if (uploadingVehiclePhoto || vehiclePhotoUrls.length >= 3) return;
    final navigator = Navigator.of(context);
    final remainingSlots = 3 - vehiclePhotoUrls.length;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xl,
                RaSpace.sm,
                RaSpace.xl,
                RaSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add breakdown evidence', style: RaText.headline),
                  const SizedBox(height: RaSpace.xs),
                  Text(
                    '$remainingSlots of 3 photo slots remaining',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              description: 'Select one or more existing photos',
              source: ImageSource.gallery,
            ),
            const _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              description: 'Open the camera for a new photo',
              source: ImageSource.camera,
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => uploadingVehiclePhoto = true);
    try {
      final picker = ImagePicker();
      final List<XFile> photos = source == ImageSource.gallery
          ? await picker.pickMultiImage(
              imageQuality: 75,
              maxWidth: 1600,
              limit: remainingSlots,
            )
          : [
              ?await navigator.push<XFile>(
                MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
              ),
            ];
      if (photos.isEmpty) return;
      final preparedPhotos = <String>[];
      for (final photo in photos) {
        final photoData = await PhotoUploadService().prepareVehiclePhoto(photo);
        if (!vehiclePhotoUrls.contains(photoData) &&
            !preparedPhotos.contains(photoData)) {
          preparedPhotos.add(photoData);
        }
        if (preparedPhotos.length >= remainingSlots) break;
      }
      if (!mounted || preparedPhotos.isEmpty) return;
      setState(() => vehiclePhotoUrls.addAll(preparedPhotos));
      await saveDraft(showConfirmation: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preparedPhotos.length == 1
                ? 'Breakdown photo added.'
                : '${preparedPhotos.length} breakdown photos added.',
          ),
        ),
      );
      if (photos.length > preparedPhotos.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate photos were skipped.')),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
    } finally {
      if (mounted) setState(() => uploadingVehiclePhoto = false);
    }
  }

  Future<void> annotateVehiclePhoto(int index) async {
    final existing = photoAnnotations
        .where((annotation) => annotation.photoIndex == index)
        .firstOrNull;
    var markerX = existing?.markerX ?? .5;
    var markerY = existing?.markerY ?? .5;
    final noteController = TextEditingController(text: existing?.note ?? '');
    final annotation = await showDialog<BreakdownPhotoAnnotation>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark the damaged area'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tap the photo to move the damage marker, then add a short note.',
                  ),
                  const SizedBox(height: RaSpace.md),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        onTapDown: (details) => setDialogState(() {
                          markerX =
                              (details.localPosition.dx / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                          markerY =
                              (details.localPosition.dy / constraints.maxHeight)
                                  .clamp(0.0, 1.0);
                        }),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(RaRadius.md),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                base64Decode(vehiclePhotoUrls[index]),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                left: markerX * constraints.maxWidth - 16,
                                top: markerY * constraints.maxHeight - 16,
                                child: const Icon(
                                  Icons.location_on,
                                  color: raDanger,
                                  size: 32,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  TextField(
                    controller: noteController,
                    maxLength: 120,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Damage note',
                      hintText: 'e.g. Deep cut on rear-left tyre',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                BreakdownPhotoAnnotation(
                  photoIndex: index,
                  markerX: markerX,
                  markerY: markerY,
                  note: noteController.text.trim(),
                ),
              ),
              child: const Text('Save Annotation'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (annotation == null || !mounted) return;
    setState(() {
      photoAnnotations.removeWhere((item) => item.photoIndex == index);
      photoAnnotations.add(annotation);
    });
    await saveDraft(showConfirmation: false);
  }

  void removeVehiclePhoto(int index) {
    setState(() {
      vehiclePhotoUrls.removeAt(index);
      final remaining = photoAnnotations
          .where((item) => item.photoIndex != index)
          .map(
            (item) => item.photoIndex > index
                ? BreakdownPhotoAnnotation(
                    photoIndex: item.photoIndex - 1,
                    markerX: item.markerX,
                    markerY: item.markerY,
                    note: item.note,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Breakdown Details'),
      actions: [
        TextButton.icon(
          onPressed: selectSavedVehicle,
          icon: const Icon(Icons.directions_car),
          label: const Text('Saved vehicles'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const AssetSlot(
                  height: 185,
                  label: 'VEHICLE HERO IMAGE\nPremium dark sedan by roadside',
                  icon: Icons.directions_car,
                  assetPath: 'assets/images/vehicle_sedan.jpg',
                ),
                Padding(
                  padding: const EdgeInsets.all(RaSpace.xl),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: StepEyebrow(step: 2, of: 4)),
                            const SizedBox(width: RaSpace.md),
                            TextButton.icon(
                              onPressed: saveDraft,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save Draft'),
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.md),
                        const FormSectionTitle(
                          Icons.directions_car_outlined,
                          'Vehicle Information',
                        ),
                        const SizedBox(height: RaSpace.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: vehicle,
                                key: ValueKey(vehicle),
                                isExpanded: true,
                                items:
                                    [
                                          'Sedan / Hatchback',
                                          'SUV',
                                          'Van',
                                          'Motorcycle',
                                          'Other',
                                        ]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  setState(() => vehicle = v!);
                                  scheduleDraftSave();
                                },
                              ),
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              child: TextFormField(
                                controller: modelController,
                                maxLength: 50,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Model / Year',
                                  hintText: 'Toyota Aqua 2018',
                                ),
                                validator: validateVehicleModelYear,
                                onChanged: (_) => scheduleDraftSave(),
                              ),
                            ),
                          ],
                        ),
                        if (vehicle == 'Other') ...[
                          const SizedBox(height: RaSpace.md),
                          TextFormField(
                            controller: customVehicleController,
                            maxLength: 40,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Other Vehicle Type',
                              hintText: 'e.g. Three Wheeler, Pickup Truck',
                              prefixIcon: Icon(Icons.directions_car_outlined),
                            ),
                            validator: (value) => vehicle == 'Other'
                                ? validateCustomVehicleType(value)
                                : null,
                            onChanged: (_) => scheduleDraftSave(),
                          ),
                        ],
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          controller: registrationController,
                          maxLength: 16,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Registration Number',
                            hintText: 'WP CAB - 1234',
                          ),
                          validator: validateVehicleRegistration,
                          onChanged: (_) => scheduleDraftSave(),
                        ),
                        const SizedBox(height: RaSpace.xxl),
                        const FormSectionTitle(
                          Icons.info_outline,
                          'Breakdown Type',
                        ),
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          readOnly: true,
                          initialValue: widget.issues.join(', '),
                          decoration: const InputDecoration(
                            labelText: 'Primary issue',
                          ),
                        ),
                        const SizedBox(height: RaSpace.md),
                        DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Emergency Priority',
                            prefixIcon: Icon(Icons.priority_high_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                            DropdownMenuItem(
                              value: 'road_blocking',
                              child: Text('Vehicle blocking road'),
                            ),
                            DropdownMenuItem(
                              value: 'safety_risk',
                              child: Text('Passenger safety risk'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => priority = value ?? 'normal');
                            scheduleDraftSave();
                          },
                        ),
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 4,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            labelText: 'Detailed description (Optional)',
                            hintText: 'Describe the symptoms...',
                            suffixIcon: IconButton(
                              tooltip: listeningForDescription
                                  ? 'Stop voice description'
                                  : 'Describe using microphone',
                              onPressed: toggleDescriptionDictation,
                              icon: Icon(
                                listeningForDescription
                                    ? Icons.stop_circle_outlined
                                    : Icons.mic_none_rounded,
                                color: listeningForDescription
                                    ? raDanger
                                    : raBlue,
                              ),
                            ),
                          ),
                          validator: validateBreakdownDescription,
                          onChanged: (_) => scheduleDraftSave(),
                        ),
                        const SizedBox(height: RaSpace.md),
                        DropdownButtonFormField<String>(
                          initialValue: partsPreference,
                          decoration: const InputDecoration(
                            labelText: 'Replacement parts preference',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'discuss',
                              child: Text('Discuss options with provider'),
                            ),
                            DropdownMenuItem(
                              value: 'budget',
                              child: Text('Budget compatible'),
                            ),
                            DropdownMenuItem(
                              value: 'branded',
                              child: Text('Branded aftermarket'),
                            ),
                            DropdownMenuItem(
                              value: 'genuine',
                              child: Text('Genuine manufacturer parts'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => partsPreference = v ?? 'discuss');
                            scheduleDraftSave();
                          },
                        ),
                        const Text(
                          'Preference only. Compatibility, availability, price and warranty must be confirmed in the provider offer.',
                        ),
                        const SizedBox(height: RaSpace.xxl),
                        const FormSectionTitle(
                          Icons.add_a_photo_outlined,
                          'Vehicle Photos (Optional)',
                        ),
                        const SizedBox(height: RaSpace.md),
                        OutlinedButton.icon(
                          onPressed:
                              uploadingVehiclePhoto ||
                                  vehiclePhotoUrls.length >= 3
                              ? null
                              : addVehiclePhotos,
                          icon: uploadingVehiclePhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            uploadingVehiclePhoto
                                ? 'Uploading photo...'
                                : 'Add vehicle photos (${vehiclePhotoUrls.length}/3)',
                          ),
                        ),
                        if (vehiclePhotoUrls.isNotEmpty) ...[
                          const SizedBox(height: RaSpace.md),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: vehiclePhotoUrls.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: RaSpace.sm),
                              itemBuilder: (context, index) {
                                final annotation = photoAnnotations
                                    .where((item) => item.photoIndex == index)
                                    .firstOrNull;
                                return GestureDetector(
                                  onTap: () => annotateVehiclePhoto(index),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          RaRadius.sm,
                                        ),
                                        child: Image.memory(
                                          base64Decode(vehiclePhotoUrls[index]),
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (annotation != null)
                                        Positioned(
                                          left: annotation.markerX * 88 - 10,
                                          top: annotation.markerY * 88 - 10,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: raDanger,
                                            size: 20,
                                          ),
                                        ),
                                      Positioned(
                                        left: 2,
                                        bottom: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit_location_alt_outlined,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 2,
                                        top: 2,
                                        child: InkWell(
                                          onTap: () =>
                                              removeVehiclePhoto(index),
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: Icon(
                                              Icons.close,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: RaSpace.xxl),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                          ),
                          onChanged: (_) => scheduleDraftSave(),
                        ),
                        const SizedBox(height: RaSpace.lg),
                        const SafetyBox(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Confirm & Next',
            onTap: () async {
              FocusScope.of(context).unfocus();
              if (formKey.currentState?.validate() ?? false) {
                final draft = buildDraft();
                await RequestDraftStore().save(draft);
                if (!context.mounted) return;
                push(context, LocationScreen(draft: draft));
              }
            },
          ),
        ],
      ),
    ),
  );
}
