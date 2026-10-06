part of '../screens.dart';

class ProviderActiveJobScreen extends StatefulWidget {
  const ProviderActiveJobScreen({
    super.key,
    this.requestId,
    this.requestData = const {},
  });
  final String? requestId;
  final Map<String, dynamic> requestData;
  @override
  State<ProviderActiveJobScreen> createState() =>
      _ProviderActiveJobScreenState();
}

class _ProviderActiveJobScreenState extends State<ProviderActiveJobScreen> {
  int status = 0;
  final statuses = const ['Accepted', 'En Route', 'Arrived', 'Completed'];
  StreamSubscription<Position>? locationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  requestSubscription;
  late Map<String, dynamic> requestData;
  bool updatingStatus = false;
  bool requestCancelled = false;
  String? locationMessage;
  LatLng? currentProviderPosition;
  RoadRoute? roadRoute;
  int routeRequestVersion = 0;
  final serviceNotesController = TextEditingController();
  List<String> servicePhotos = <String>[];
  bool savingDocumentation = false;

  Future<void> withdraw() async {
    final reason = await _adminReason(
      context,
      'Why can you no longer attend this job?',
    );
    if (reason == null || !mounted || widget.requestId == null) return;
    setState(() => updatingStatus = true);
    try {
      await RequestService().withdrawProvider(widget.requestId!, reason);
      if (mounted) replace(context, const ProviderShell());
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => updatingStatus = false);
    }
  }

  static const backendStatuses = [
    'accepted',
    'en_route',
    'arrived',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    requestData = Map<String, dynamic>.from(widget.requestData);
    status = backendStatuses.indexOf(
      requestData['status'] as String? ?? 'accepted',
    );
    requestCancelled = requestData['status'] == 'cancelled';
    serviceNotesController.text = requestData['serviceNotes'] as String? ?? '';
    servicePhotos =
        (requestData['servicePhotoData'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    if (status < 0) status = 0;
    if (widget.requestId != null) {
      requestSubscription = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final data = snapshot.data();
              if (!mounted || data == null) return;
              final nextStatus = backendStatuses.indexOf(
                data['status'] as String? ?? '',
              );
              setState(() {
                requestData = data;
                requestCancelled = data['status'] == 'cancelled';
                if (nextStatus >= 0) status = nextStatus;
                servicePhotos =
                    (data['servicePhotoData'] as List<dynamic>? ?? const [])
                        .whereType<String>()
                        .toList();
              });
            },
            onError: (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to receive live request updates.'),
                  ),
                );
              }
            },
          );
    }
    startLocationSharing();
  }

  Future<void> startLocationSharing() async {
    if (widget.requestId == null) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          locationMessage =
              'Location permission is required to share your live position.';
        });
      }
      return;
    }
    locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        ).listen(
          (position) {
            if (mounted) {
              setState(() {
                currentProviderPosition = LatLng(
                  position.latitude,
                  position.longitude,
                );
                locationMessage = null;
              });
            }
            unawaited(
              refreshProviderRoute(
                LatLng(position.latitude, position.longitude),
              ),
            );
            RequestService().updateProviderLocation(
              widget.requestId!,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          },
          onError: (_) {
            if (mounted) {
              setState(
                () => locationMessage = 'Live location sharing stopped.',
              );
            }
          },
        );
  }

  Future<void> refreshProviderRoute(LatLng origin) async {
    final latitude = (requestData['latitude'] as num?)?.toDouble();
    final longitude = (requestData['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    final version = ++routeRequestVersion;
    try {
      final result = await const RouteService().fetchDrivingRoute(
        origin: origin,
        destination: LatLng(latitude, longitude),
      );
      if (!mounted || version != routeRequestVersion) return;
      setState(() => roadRoute = result);
    } catch (_) {
      if (!mounted || version != routeRequestVersion) return;
      setState(() => locationMessage = 'Road route ETA is unavailable.');
    }
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    requestSubscription?.cancel();
    serviceNotesController.dispose();
    super.dispose();
  }

  Future<void> addDocumentationPhoto() async {
    if (servicePhotos.length >= 3 || widget.requestId == null) return;
    final navigator = Navigator.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => const SafeArea(
        child: Wrap(
          children: [
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              source: ImageSource.camera,
            ),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              source: ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
            maxWidth: 1200,
          );
    if (photo == null || !mounted) return;
    setState(() => savingDocumentation = true);
    try {
      final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);
      final updated = [...servicePhotos, encoded];
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: updated,
      );
      if (mounted) setState(() => servicePhotos = updated);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add documentation: $error')),
        );
    } finally {
      if (mounted) setState(() => savingDocumentation = false);
    }
  }

  Future<void> saveDocumentation() async {
    if (widget.requestId == null || savingDocumentation) return;
    setState(() => savingDocumentation = true);
    try {
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: servicePhotos,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service documentation saved.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save notes: $error')));
    } finally {
      if (mounted) setState(() => savingDocumentation = false);
    }
  }

  Future<void> removeDocumentationPhoto(int index) async {
    if (widget.requestId == null || savingDocumentation) return;
    final updated = [...servicePhotos]..removeAt(index);
    setState(() => servicePhotos = updated);
    try {
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: updated,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove the photo.')),
        );
      }
    }
  }

  Future<void> advanceStatus() async {
    if (updatingStatus || widget.requestId == null || requestCancelled) return;
    if (status == 3) {
      replace(
        context,
        ProviderCompletedScreen(
          requestId: widget.requestId!,
          requestData: requestData,
        ),
      );
      return;
    }
    int? finalCost;
    if (status == 2) {
      finalCost = await requestFinalCost();
      if (finalCost == null || !mounted) return;
    }
    setState(() => updatingStatus = true);
    try {
      if (status == 2) {
        await RequestService().updateProviderDocumentation(
          widget.requestId!,
          serviceNotes: serviceNotesController.text,
          servicePhotoData: servicePhotos,
        );
        await RequestService().completeProviderJob(
          widget.requestId!,
          finalCost!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completion submitted. Waiting for driver confirmation.',
              ),
            ),
          );
        }
      } else {
        await RequestService().advanceProviderStatus(
          widget.requestId!,
          backendStatuses[status + 1],
        );
        try {
          await RequestService().updateProviderDocumentation(
            widget.requestId!,
            serviceNotes: serviceNotesController.text,
            servicePhotoData: servicePhotos,
          );
        } catch (_) {
          // Status progression must not be blocked by an optional notes save.
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update job status: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => updatingStatus = false);
    }
  }

  Future<int?> requestFinalCost() async {
    final approved = (requestData['estimatedCost'] as num?)?.toInt() ?? 0;
    final protected = requestData['workflowVersion'] == 2;
    final controller = TextEditingController(text: '$approved');
    final costRoute = DialogRoute<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final amount = int.tryParse(controller.text);
          final changed = protected && amount != approved;
          return AlertDialog(
            icon: const Icon(Icons.receipt_long_outlined),
            title: const Text('Confirm final charge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Driver-approved total: Rs. $approved'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onChanged: (_) => refresh(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Final amount (Rs.)',
                  ),
                ),
                if (changed)
                  const Text(
                    'A changed price needs a reason and driver approval. An increase also needs photo evidence. The job will remain open while approval is pending.',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: amount == null || amount < 0 || amount > 10000000
                    ? null
                    : () => Navigator.pop(dialogContext, amount),
                child: Text(
                  changed ? 'Request price approval' : 'Complete Job',
                ),
              ),
            ],
          );
        },
      ),
    );
    final value = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(costRoute);
    await costRoute.completed;
    controller.dispose();
    if (value == null || !mounted) return null;
    if (protected && value != approved) {
      final quote = await requestProviderQuote(context, {
        ...requestData,
        'repairRevision': true,
        'proposedTotal': value,
      });
      if (quote == null || !mounted) return null;
      try {
        await RequestService().proposeRepair(widget.requestId!, quote);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Price change sent. Wait for driver approval, then complete the job at the approved total.',
              ),
            ),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not send the price change. Check access, connection and whether another change is pending.',
              ),
            ),
          );
      }
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final data = requestData;
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final driverName = data['driverName'] as String? ?? 'Nearby Driver';
    final driverPhone = data['driverPhone'] as String? ?? '';
    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.isNotEmpty).join(' - ');
    return ProviderScaffold(
      appBar: AppBar(title: const Text('Active Assistance')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  if (widget.requestId != null &&
                      (data['arrivalVerificationRequired'] != true ||
                          data['arrivalConfirmedBy'] == data['driverId']))
                    RepairQuotePanel(
                      requestId: widget.requestId!,
                      isProvider: true,
                    ),
                  Container(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [providerSurfaceStrong, providerRoyalBlue],
                      ),
                      borderRadius: BorderRadius.circular(RaRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CURRENT STATUS',
                              style: RaText.eyebrowOnDark,
                            ),
                            const Spacer(),
                            StatusPill(
                              label: requestCancelled ? 'CANCELLED' : 'LIVE',
                              tone: requestCancelled
                                  ? RaTone.danger
                                  : RaTone.warning,
                              dot: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Row(
                          children: [
                            Icon(
                              status == 0
                                  ? Icons.task_alt
                                  : status == 1
                                  ? Icons.local_shipping_outlined
                                  : status == 2
                                  ? Icons.location_on_outlined
                                  : Icons.verified_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Text(
                              requestCancelled
                                  ? 'Request Cancelled'
                                  : statuses[status],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.lg),
                        Container(
                          padding: const EdgeInsets.all(RaSpace.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(RaRadius.sm),
                          ),
                          child: StatusTimeline(
                            statuses: statuses,
                            current: status,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RaRadius.md),
                    child: SizedBox(
                      height: 250,
                      child: MapMock(
                        position: LatLng(latitude, longitude),
                        providerPosition: currentProviderPosition,
                        routePoints: roadRoute?.points,
                        showProviders: currentProviderPosition != null,
                        showRoute: roadRoute != null,
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => openMapNavigation(
                        context,
                        latitude: latitude,
                        longitude: longitude,
                      ),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Start Voice Navigation'),
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        children: [
                          SummaryRow('Driver', driverName),
                          SummaryRow(
                            'Vehicle',
                            vehicle.isEmpty
                                ? 'Vehicle details unavailable'
                                : vehicle,
                          ),
                          SummaryRow(
                            'Breakdown',
                            data['issue'] as String? ?? 'Roadside assistance',
                          ),
                          SummaryRow(
                            'Location',
                            data['locationLabel'] as String? ??
                                'Pinned location',
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: driverPhone.isEmpty
                                      ? null
                                      : () => showCallPrompt(
                                          context,
                                          name: driverName,
                                          number: driverPhone,
                                        ),
                                  icon: const Icon(Icons.call),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.requestId == null
                                      ? null
                                      : () => push(
                                          context,
                                          ChatScreen(
                                            requestId: widget.requestId,
                                            peerName: driverName,
                                            peerPhone: driverPhone,
                                          ),
                                        ),
                                  icon: _UnreadChatIcon(
                                    requestId: widget.requestId,
                                    seenField: 'providerMessagesSeenAt',
                                  ),
                                  label: const Text('Chat'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  if (locationMessage != null) ...[
                    InlineMessage(
                      icon: Icons.location_off_outlined,
                      text: locationMessage!,
                    ),
                    const SizedBox(height: RaSpace.lg),
                  ],
                  InfoStrip(
                    icon: currentProviderPosition == null
                        ? Icons.location_searching
                        : Icons.share_location_outlined,
                    title: currentProviderPosition == null
                        ? 'Finding your live location'
                        : 'Live location sharing active',
                    value: currentProviderPosition == null
                        ? 'Allow location access and keep this page open.'
                        : roadRoute == null
                        ? 'Calculating the fastest driving route...'
                        : '${roadRoute!.distanceKm.toStringAsFixed(1)} km by road · ${roadRoute!.durationMinutes} min${roadRoute!.trafficAware ? ' with live traffic' : ''}',
                  ),
                  const SizedBox(height: RaSpace.lg),
                  if (requestCancelled) ...[
                    const InlineMessage(
                      icon: Icons.cancel_outlined,
                      text: 'The driver cancelled this assistance request.',
                    ),
                    const SizedBox(height: RaSpace.lg),
                  ],
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Documentation', style: RaText.headline),
                      ),
                      Text(
                        '${servicePhotos.length}/3 added',
                        style: RaText.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.md),
                  SizedBox(
                    height: 105,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (servicePhotos.length < 3)
                          InkWell(
                            onTap: savingDocumentation
                                ? null
                                : addDocumentationPhoto,
                            borderRadius: BorderRadius.circular(RaRadius.md),
                            child: Container(
                              width: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  RaRadius.md,
                                ),
                                border: Border.all(
                                  color: providerAction,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  savingDocumentation
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: providerAction,
                                        ),
                                  const SizedBox(height: 6),
                                  const Text('Add Photo', style: RaText.label),
                                ],
                              ),
                            ),
                          ),
                        for (
                          var index = 0;
                          index < servicePhotos.length;
                          index++
                        ) ...[
                          if (index > 0 || servicePhotos.length < 3)
                            const SizedBox(width: RaSpace.sm),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  RaRadius.md,
                                ),
                                child: Image.memory(
                                  base64Decode(servicePhotos[index]),
                                  width: 122,
                                  height: 105,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(28, 28),
                                    padding: EdgeInsets.zero,
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      removeDocumentationPhoto(index),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  const Text('Service Notes', style: RaText.headline),
                  const SizedBox(height: RaSpace.sm),
                  TextField(
                    controller: serviceNotesController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'Add arrival notes, work completed or important observations...',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          savingDocumentation ||
                              data['completionState'] == 'pending'
                          ? null
                          : saveDocumentation,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Notes'),
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                ],
              ),
            ),
            if (!requestCancelled && status < 2)
              TextButton(
                onPressed: updatingStatus ? null : withdraw,
                child: const Text('Cancel attendance - give reason'),
              ),
            if (status == 2 &&
                data['arrivalVerificationRequired'] == true &&
                data['arrivalConfirmedBy'] == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Waiting for driver arrival confirmation. Do not begin repair work until the driver confirms.',
                ),
              ),
            BottomAction(
              label: updatingStatus
                  ? 'Updating status...'
                  : data['completionState'] == 'pending'
                  ? 'Waiting for driver confirmation'
                  : requestCancelled
                  ? 'Back to Dashboard'
                  : status == 3
                  ? 'Finish Job'
                  : 'Mark as ${statuses[status + 1]}',
              enabled:
                  !updatingStatus &&
                  data['completionState'] != 'pending' &&
                  (status != 2 ||
                      data['arrivalVerificationRequired'] != true ||
                      data['arrivalConfirmedBy'] == data['driverId']) &&
                  widget.requestId != null &&
                  (requestCancelled ||
                      status != 2 ||
                      data['workflowVersion'] != 2 ||
                      (data['pendingRepairId'] == null &&
                          (data['approvedQuoteType'] != 'inspection' ||
                              data['approvedRepairId'] != null))),
              onTap: requestCancelled
                  ? () => replace(context, const ProviderShell())
                  : advanceStatus,
            ),
          ],
        ),
      ),
    );
  }
}
