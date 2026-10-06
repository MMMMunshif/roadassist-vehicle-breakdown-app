part of '../../screens.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key, required this.draft, this.requestId});
  final RequestDraft draft;
  final String? requestId;
  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestListener;
  Timer? providerResponseTimer;
  late final AnimationController pulseController;
  String requestStatus = 'searching';
  String? requestError;
  bool searchingAllProviders = false;
  bool navigatingToTracking = false;
  late String currentLocationLabel;
  late RequestDraft editableDraft;

  Future<void> editPendingRequest() async {
    if (widget.requestId == null || requestStatus != 'searching') return;
    final descriptionController = TextEditingController(
      text: editableDraft.description,
    );
    final notesController = TextEditingController(text: editableDraft.notes);
    final locationController = TextEditingController(
      text: editableDraft.location,
    );
    final landmarkController = TextEditingController(
      text: editableDraft.landmark,
    );
    final photos = List<String>.from(editableDraft.vehiclePhotoUrls);
    var latitude = editableDraft.latitude;
    var longitude = editableDraft.longitude;
    var accuracy = editableDraft.locationAccuracyMeters;
    var locating = false;
    final updatedDraft = await showDialog<RequestDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit pending request'),
          content: SizedBox(
            width: 390,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Breakdown description',
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Additional notes',
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  TextField(
                    controller: locationController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      suffixIcon: IconButton(
                        tooltip: 'Refresh current GPS',
                        onPressed: locating
                            ? null
                            : () async {
                                setDialogState(() => locating = true);
                                try {
                                  final position =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings:
                                            const LocationSettings(
                                              accuracy: LocationAccuracy.high,
                                            ),
                                      );
                                  latitude = position.latitude;
                                  longitude = position.longitude;
                                  accuracy = position.accuracy;
                                  locationController.text =
                                      'Current GPS (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
                                } finally {
                                  setDialogState(() => locating = false);
                                }
                              },
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  TextField(
                    controller: landmarkController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Nearby landmark',
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: photos.length >= 3
                              ? null
                              : () async {
                                  final picked = await ImagePicker()
                                      .pickMultiImage(
                                        imageQuality: 75,
                                        maxWidth: 1600,
                                        limit: 3 - photos.length,
                                      );
                                  for (final photo in picked) {
                                    if (photos.length >= 3) break;
                                    final encoded = await PhotoUploadService()
                                        .prepareVehiclePhoto(photo);
                                    if (!photos.contains(encoded)) {
                                      photos.add(encoded);
                                    }
                                  }
                                  setDialogState(() {});
                                },
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text('Photos (${photos.length}/3)'),
                        ),
                      ),
                    ],
                  ),
                  if (photos.isNotEmpty)
                    Wrap(
                      spacing: RaSpace.sm,
                      children: List.generate(
                        photos.length,
                        (index) => InputChip(
                          label: Text('Photo ${index + 1}'),
                          onDeleted: () =>
                              setDialogState(() => photos.removeAt(index)),
                        ),
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
              onPressed: () {
                final description = descriptionController.text.trim();
                final location = locationController.text.trim();
                if (location.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  editableDraft.copyWith(
                    description: description,
                    notes: notesController.text.trim(),
                    location: location,
                    landmark: landmarkController.text.trim(),
                    latitude: latitude,
                    longitude: longitude,
                    locationAccuracyMeters: accuracy,
                    vehiclePhotoUrls: photos,
                    photoAnnotations:
                        listEquals(photos, editableDraft.vehiclePhotoUrls)
                        ? editableDraft.photoAnnotations
                        : const [],
                  ),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
    descriptionController.dispose();
    notesController.dispose();
    locationController.dispose();
    landmarkController.dispose();
    if (updatedDraft == null || !mounted) return;
    try {
      await RequestService().updateSearchingRequest(
        widget.requestId!,
        updatedDraft,
      );
      await RequestDraftStore().save(updatedDraft);
      if (!mounted) return;
      setState(() {
        editableDraft = updatedDraft;
        currentLocationLabel = updatedDraft.location;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pending request updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to edit. The provider may have already accepted.',
          ),
        ),
      );
    }
  }

  Future<void> cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: raDanger),
        title: const Text('Cancel assistance request?'),
        content: const Text(
          'The provider search will stop and this request will not be submitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Searching'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: raDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      try {
        if (widget.requestId != null) {
          await RequestService().cancelRequest(widget.requestId!);
        }
        if (!mounted) return;
        replace(context, const DriverShell());
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to cancel the request. Try again.'),
            ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    currentLocationLabel = widget.draft.location;
    editableDraft = widget.draft;
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    if (widget.requestId == null) {
      requestStatus = 'not_submitted';
      requestError = 'This request was not saved. Sign in and submit again.';
    } else {
      requestListener = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final data = snapshot.data();
              if (!mounted) return;
              if (data == null) {
                setState(() => requestError = 'Request could not be found.');
                return;
              }
              final status = data['status'] as String? ?? 'searching';
              final locationLabel =
                  data['locationLabel'] as String? ?? widget.draft.location;
              final preferredProviderId =
                  data['preferredProviderId'] as String? ?? '';
              if (status == 'searching' && preferredProviderId.isNotEmpty) {
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
                final latitude = (data['latitude'] as num?)?.toDouble();
                final longitude = (data['longitude'] as num?)?.toDouble();
                replace(
                  context,
                  TrackingScreen(
                    draft: editableDraft.copyWith(
                      location: locationLabel,
                      latitude: latitude,
                      longitude: longitude,
                      landmark:
                          data['landmark'] as String? ?? editableDraft.landmark,
                      locationAccuracyMeters:
                          (data['locationAccuracyMeters'] as num?)?.toDouble(),
                    ),
                    requestId: widget.requestId,
                  ),
                );
              } else {
                setState(() {
                  requestStatus = status;
                  currentLocationLabel = locationLabel;
                  editableDraft = editableDraft.copyWith(
                    description:
                        data['description'] as String? ??
                        editableDraft.description,
                    notes: data['notes'] as String? ?? editableDraft.notes,
                    location: locationLabel,
                    landmark:
                        data['landmark'] as String? ?? editableDraft.landmark,
                    vehiclePhotoUrls:
                        (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
                            .whereType<String>()
                            .toList(),
                  );
                  requestError = null;
                  searchingAllProviders =
                      widget.draft.preferredProviderId.isNotEmpty &&
                      (data['preferredProviderId'] as String? ?? '').isEmpty;
                });
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  requestError = 'Connection lost. Waiting to reconnect...';
                });
              }
            },
          );
    }
  }

  void _scheduleProviderTimeout(Map<String, dynamic> data) {
    if (providerResponseTimer != null || widget.requestId == null) return;
    const responseWindow = Duration(seconds: 90);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final elapsed = createdAt == null
        ? Duration.zero
        : DateTime.now().difference(createdAt);
    final remaining = elapsed >= responseWindow
        ? Duration.zero
        : responseWindow - elapsed;
    providerResponseTimer = Timer(remaining, () async {
      providerResponseTimer = null;
      try {
        await RequestService().expandProviderSearch(widget.requestId!);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to expand the provider search yet.'),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    requestListener?.cancel();
    providerResponseTimer?.cancel();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xxl,
                RaSpace.xl,
                RaSpace.xxl,
                RaSpace.lg,
              ),
              children: [
                if (widget.requestId != null)
                  QuoteOffers(requestId: widget.requestId!),
                Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(
                    label: requestStatus == 'cancelled'
                        ? 'REQUEST CANCELLED'
                        : requestStatus == 'not_submitted'
                        ? 'NOT SUBMITTED'
                        : searchingAllProviders
                        ? 'EXPANDING SEARCH'
                        : 'SEARCHING NEARBY',
                    tone:
                        requestStatus == 'cancelled' ||
                            requestStatus == 'not_submitted'
                        ? RaTone.danger
                        : RaTone.info,
                  ),
                ),
                const SizedBox(height: RaSpace.xxl),
                Center(
                  child: AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) => Transform.scale(
                      scale: 0.88 + (pulseController.value * 0.12),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            raPale,
                            const Color(0xFFAFC3FF),
                            pulseController.value,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: raBlue.withValues(
                                alpha: 0.18 + pulseController.value * 0.18,
                              ),
                              blurRadius: 18 + pulseController.value * 18,
                              spreadRadius: pulseController.value * 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: RotationTransition(
                            turns: pulseController,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: const BoxDecoration(
                                color: raNavy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_searching,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xxl),
                Text(
                  'Finding Your\nRescue Team',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                Text(
                  requestError ??
                      (requestStatus == 'cancelled'
                          ? 'This assistance request has been cancelled.'
                          : searchingAllProviders
                          ? '${widget.draft.provider} was unavailable. Searching other matching providers now.'
                          : widget.draft.provider.isEmpty
                          ? 'Sending your request to an available certified provider.'
                          : 'Sending your request to ${widget.draft.provider}.'),
                  textAlign: TextAlign.center,
                  style: requestError == null
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: raDanger),
                ),
                if (requestStatus == 'searching' &&
                    widget.draft.preferredProviderId.isNotEmpty &&
                    !searchingAllProviders) ...[
                  const SizedBox(height: RaSpace.lg),
                  const InlineMessage(
                    icon: Icons.schedule_outlined,
                    text:
                        'If this provider does not respond within 90 seconds, we will automatically search other matching providers.',
                  ),
                ],
                const SizedBox(height: RaSpace.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: StatusPill(
                            label: requestStatus == 'cancelled'
                                ? 'Cancelled'
                                : requestStatus == 'not_submitted'
                                ? 'Not submitted'
                                : 'Searching',
                            tone:
                                requestStatus == 'cancelled' ||
                                    requestStatus == 'not_submitted'
                                ? RaTone.danger
                                : RaTone.info,
                          ),
                        ),
                        SummaryRow(
                          'Request ID',
                          widget.requestId ?? 'Not submitted',
                        ),
                        SummaryRow('Assistance Type', widget.draft.issue),
                        SummaryRow('Current Location', currentLocationLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.xxl,
              RaSpace.sm,
              RaSpace.xxl,
              RaSpace.lg,
            ),
            child: requestStatus == 'searching'
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: editPendingRequest,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: RaSpace.sm),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: cancelRequest,
                          style: TextButton.styleFrom(
                            foregroundColor: raDanger,
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: () => replace(context, const DriverShell()),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to Home'),
                  ),
          ),
        ],
      ),
    ),
  );
}
