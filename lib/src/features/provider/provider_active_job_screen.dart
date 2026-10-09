part of '../../screens.dart';

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
  static const backendStatuses = [
    'accepted',
    'en_route',
    'arrived',
    'completed',
  ];

  static const statuses = ['Accepted', 'En Route', 'Arrived', 'Completed'];

  int status = 0;

  late Map<String, dynamic> requestData;

  StreamSubscription<Position>? locationSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  requestSubscription;

  final serviceNotesController = TextEditingController();

  List<String> servicePhotos = [];

  LatLng? currentProviderPosition;
  RoadRoute? roadRoute;

  String? locationMessage;

  int routeRequestVersion = 0;

  Map<String, dynamic>? completionReportDraft;
  bool updatingStatus = false;
  bool savingDocumentation = false;
  bool requestCancelled = false;

  @override
  void initState() {
    super.initState();

    requestData = Map<String, dynamic>.from(widget.requestData);

    status = backendStatuses.indexOf(
      requestData['status'] as String? ?? 'accepted',
    );

    if (status < 0) {
      status = 0;
    }

    requestCancelled = requestData['status'] == 'cancelled';

    serviceNotesController.text = requestData['serviceNotes'] as String? ?? '';

    servicePhotos =
        (requestData['servicePhotoData'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();

    final requestId = widget.requestId;

    if (requestId != null) {
      requestSubscription = RequestService()
          .watchRequest(requestId)
          .listen(
            _handleRequestUpdate,
            onError: (_) {
              if (!mounted) return;

              setState(() {
                locationMessage = 'Unable to receive live request updates.';
              });
            },
          );

      unawaited(startLocationSharing());
    }
  }

  @override
  void dispose() {
    locationSubscription?.cancel();

    requestSubscription?.cancel();

    serviceNotesController.dispose();

    super.dispose();
  }

  void _handleRequestUpdate(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!mounted || data == null) {
      return;
    }

    final nextStatus = backendStatuses.indexOf(data['status'] as String? ?? '');

    setState(() {
      requestData = data;

      requestCancelled = data['status'] == 'cancelled';

      if (nextStatus >= 0) {
        status = nextStatus;
      }

      servicePhotos = (data['servicePhotoData'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();

      final notes = data['serviceNotes'] as String? ?? '';

      if (!serviceNotesController.text.trim().isNotEmpty) {
        serviceNotesController.text = notes;
      }
    });
  }

  Future<void> startLocationSharing() async {
    final requestId = widget.requestId;

    if (requestId == null || requestCancelled || status >= 3) {
      return;
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        if (!mounted) return;

        setState(() {
          locationMessage =
              'Turn on location services to share your live position.';
        });

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          locationMessage =
              'Location permission is required for live provider tracking.';
        });

        return;
      }

      await locationSubscription?.cancel();

      locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            ),
          ).listen(
            (position) {
              final point = LatLng(position.latitude, position.longitude);

              if (mounted) {
                setState(() {
                  currentProviderPosition = point;

                  locationMessage = null;
                });
              }

              unawaited(
                RequestService().updateProviderLocation(
                  requestId,
                  latitude: position.latitude,
                  longitude: position.longitude,
                ),
              );

              unawaited(refreshProviderRoute(point));
            },
            onError: (_) {
              if (!mounted) return;

              setState(() {
                locationMessage = 'Live location sharing stopped.';
              });
            },
          );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        locationMessage = 'Unable to start live location sharing.';
      });
    }
  }

  Future<void> refreshProviderRoute(LatLng origin) async {
    final latitude = (requestData['latitude'] as num?)?.toDouble();

    final longitude = (requestData['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return;
    }

    final version = ++routeRequestVersion;

    try {
      final result = await const RouteService().fetchDrivingRoute(
        origin: origin,
        destination: LatLng(latitude, longitude),
      );

      if (!mounted || version != routeRequestVersion) {
        return;
      }

      setState(() {
        roadRoute = result;
      });
    } catch (_) {
      if (!mounted || version != routeRequestVersion) {
        return;
      }

      setState(() {
        locationMessage = 'Road route and ETA are temporarily unavailable.';
      });
    }
  }

  Future<void> withdraw() async {
    final requestId = widget.requestId;

    if (requestId == null || updatingStatus) {
      return;
    }

    final reason = await _adminReason(
      context,
      'Why can you no longer attend this job?',
    );

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      updatingStatus = true;
    });

    try {
      await RequestService().withdrawProvider(requestId, reason);

      if (!mounted) return;

      replace(context, const ProviderShell());
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() {
          updatingStatus = false;
        });
      }
    }
  }

  Future<void> addDocumentationPhoto() async {
    final requestId = widget.requestId;

    if (requestId == null || savingDocumentation || servicePhotos.length >= 3) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return const SafeArea(
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
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
            maxWidth: 1200,
          );

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      savingDocumentation = true;
    });

    try {
      final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);

      final updated = [...servicePhotos, encoded];

      await RequestService().updateProviderDocumentation(
        requestId,
        serviceNotes: serviceNotesController.text.trim(),
        servicePhotoData: updated,
      );

      if (!mounted) return;

      setState(() {
        servicePhotos = updated;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add documentation: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingDocumentation = false;
        });
      }
    }
  }

  Future<void> removeDocumentationPhoto(int index) async {
    final requestId = widget.requestId;

    if (requestId == null ||
        savingDocumentation ||
        index < 0 ||
        index >= servicePhotos.length) {
      return;
    }

    final previous = [...servicePhotos];

    final updated = [...servicePhotos]..removeAt(index);

    setState(() {
      servicePhotos = updated;

      savingDocumentation = true;
    });

    try {
      await RequestService().updateProviderDocumentation(
        requestId,
        serviceNotes: serviceNotesController.text.trim(),
        servicePhotoData: updated,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        servicePhotos = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove the photo.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingDocumentation = false;
        });
      }
    }
  }

  Future<void> saveDocumentation() async {
    final requestId = widget.requestId;

    if (requestId == null || savingDocumentation) {
      return;
    }

    setState(() {
      savingDocumentation = true;
    });

    try {
      await RequestService().updateProviderDocumentation(
        requestId,
        serviceNotes: serviceNotesController.text.trim(),
        servicePhotoData: servicePhotos,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service documentation saved.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save documentation: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingDocumentation = false;
        });
      }
    }
  }

  Future<void> advanceStatus() async {
    final requestId = widget.requestId;

    if (requestId == null || updatingStatus || requestCancelled) {
      return;
    }

    if (status == 3) {
      replace(
        context,
        ProviderCompletedScreen(requestId: requestId, requestData: requestData),
      );

      return;
    }

    int? finalCost;
    CompletionReport? report;

    if (status == 2) {
      report = await requestCompletionReport(context, {
        ...requestData,
        if (completionReportDraft != null)
          'completionReport': completionReportDraft,
      });
      if (report == null || !mounted) return;
      completionReportDraft = report.toMap();
      finalCost = await requestFinalCost();

      if (finalCost == null || !mounted) {
        return;
      }
    }

    setState(() {
      updatingStatus = true;
    });

    try {
      if (status == 2) {
        await RequestService().updateProviderDocumentation(
          requestId,
          serviceNotes: serviceNotesController.text.trim(),
          servicePhotoData: servicePhotos,
        );

        await RequestService().completeProviderJob(
          requestId,
          finalCost!,
          report: report!,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completion submitted. Waiting for driver confirmation.',
            ),
          ),
        );

        return;
      }

      await RequestService().advanceProviderStatus(
        requestId,
        backendStatuses[status + 1],
      );

      try {
        await RequestService().updateProviderDocumentation(
          requestId,
          serviceNotes: serviceNotesController.text.trim(),
          servicePhotoData: servicePhotos,
        );
      } catch (_) {
        // Optional notes save must not block workflow progression.
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update job status: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingStatus = false;
        });
      }
    }
  }

  Future<int?> requestFinalCost() async {
    final approved = (requestData['estimatedCost'] as num?)?.toInt() ?? 0;

    final protected = requestData['workflowVersion'] == 2;

    final controller = TextEditingController(text: '$approved');

    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            final amount = int.tryParse(controller.text.trim());

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
                    onChanged: (_) {
                      refresh(() {});
                    },
                    decoration: const InputDecoration(
                      labelText: 'Final amount (Rs.)',
                    ),
                  ),

                  if (changed) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'A changed total requires driver approval before completion.',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: amount == null || amount < 0 || amount > 10000000
                      ? null
                      : () {
                          Navigator.pop(dialogContext, amount);
                        },
                  child: Text(changed ? 'Request Approval' : 'Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (value == null || !mounted) {
      return null;
    }

    if (protected && value != approved) {
      final quote = await requestProviderQuote(context, {
        ...requestData,
        'repairRevision': true,
        'proposedTotal': value,
      });

      if (quote == null || !mounted) {
        return null;
      }

      try {
        await RequestService().proposeRepair(widget.requestId!, quote);

        if (!mounted) return null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Price revision sent. Wait for driver approval before completing the job.',
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send the revised price.')),
        );
      }

      return null;
    }

    return value;
  }

  String _statusTitle() {
    if (requestCancelled) {
      return 'Job cancelled';
    }

    if (requestData['completionState'] == 'pending') {
      return 'Waiting for driver confirmation';
    }

    return switch (status) {
      0 => 'Job accepted',
      1 => 'Travelling to driver',
      2 => 'Arrived at breakdown',
      _ => 'Job completed',
    };
  }

  String _statusDescription() {
    if (requestCancelled) {
      return requestData['cancellationReason'] as String? ??
          'This roadside assistance job is no longer active.';
    }

    if (requestData['completionState'] == 'pending') {
      return 'The completion has been submitted. The driver must review and confirm the work.';
    }

    return switch (status) {
      0 => 'Review the request and start travelling when you are ready.',
      1 =>
        'Your live location is being shared with the driver while travelling.',
      2 =>
        'Confirm arrival, document the work and complete only after required approvals.',
      _ => 'The roadside assistance job has been completed.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = requestData;

    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final latitude = (data['latitude'] as num?)?.toDouble();

    final longitude = (data['longitude'] as num?)?.toDouble();

    final hasDriverLocation = latitude != null && longitude != null;

    final driverName = data['driverName'] as String? ?? 'Driver';

    final driverPhone = data['driverPhone'] as String? ?? '';

    final location =
        data['locationLabel'] as String? ??
        data['location'] as String? ??
        'Location unavailable';

    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    final completionPending = data['completionState'] == 'pending';

    final waitingForArrivalConfirmation =
        status == 2 &&
        data['arrivalVerificationRequired'] == true &&
        data['arrivalConfirmedBy'] == null;

    final repairReady =
        data['workflowVersion'] != 2 ||
        (data['pendingRepairId'] == null &&
            (data['approvedQuoteType'] != 'inspection' ||
                data['approvedRepairId'] != null));

    return RaProviderScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Active Assistance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: _WelcomeThemeToggle(),
          ),
        ],
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
                  _RaProviderActiveStatusCard(
                    title: _statusTitle(),
                    description: _statusDescription(),
                    status: status,
                    cancelled: requestCancelled,
                  ),

                  if (widget.requestId != null &&
                      (data['arrivalVerificationRequired'] != true ||
                          data['arrivalConfirmedBy'] == data['driverId'])) ...[
                    const SizedBox(height: 13),

                    RepairQuotePanel(
                      requestId: widget.requestId!,
                      isProvider: true,
                    ),
                  ],

                  const SizedBox(height: 14),

                  if (hasDriverLocation)
                    _RaProviderActiveMap(
                      latitude: latitude,
                      longitude: longitude,
                      providerPosition: currentProviderPosition,
                      roadRoute: roadRoute,
                      locationMessage: locationMessage,
                      location: location,
                    )
                  else
                    _RaProviderActiveNotice(
                      icon: Icons.location_off_outlined,
                      title: 'Driver coordinates unavailable',
                      message: location,
                      tone: colors.error,
                    ),

                  const SizedBox(height: 14),

                  _RaProviderActiveDriverCard(
                    name: driverName,
                    phone: driverPhone,
                    requestId: widget.requestId,
                  ),

                  const SizedBox(height: 14),

                  _RaProviderActiveSummary(
                    issue: requestIssueLabel(data),
                    vehicle: vehicle,
                    location: location,
                    approvedTotal: (data['estimatedCost'] as num?)?.toInt(),
                  ),

                  if (waitingForArrivalConfirmation) ...[
                    const SizedBox(height: 14),

                    const _RaProviderActiveNotice(
                      icon: Icons.person_pin_circle_outlined,
                      title: 'Waiting for driver',
                      message:
                          'The driver must confirm that you have physically arrived before repair work begins.',
                      tone: raGold,
                    ),
                  ],

                  if (status == 2 && !requestCancelled) ...[
                    const SizedBox(height: 24),

                    const _RaProviderActiveHeading(
                      title: 'Service documentation',
                      subtitle:
                          'Record notes and evidence of the work performed.',
                    ),

                    const SizedBox(height: 10),

                    _RaProviderDocumentationCard(
                      controller: serviceNotesController,
                      photos: servicePhotos,
                      saving: savingDocumentation,
                      onAddPhoto: addDocumentationPhoto,
                      onRemovePhoto: removeDocumentationPhoto,
                      onSave: saveDocumentation,
                    ),
                  ],

                  if (!requestCancelled && status < 2) ...[
                    const SizedBox(height: 15),

                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      onPressed: updatingStatus ? null : withdraw,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cannot Attend This Job'),
                    ),
                  ],

                  if (completionPending && widget.requestId != null) ...[
                    CompletionReviewPanel(
                      requestId: widget.requestId!,
                      isProvider: true,
                    ),
                    const SizedBox(height: 14),

                    const _RaProviderActiveNotice(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Driver confirmation pending',
                      message:
                          'No further status action is required until the driver reviews the submitted completion.',
                      tone: raSuccess,
                    ),
                  ],
                ],
              ),
            ),

            _RaProviderActiveBottomBar(
              label: requestCancelled
                  ? 'Back to Dashboard'
                  : completionPending
                  ? 'Waiting for Driver Confirmation'
                  : status == 3
                  ? 'Finish Job'
                  : 'Mark as ${statuses[status + 1]}',
              enabled:
                  !updatingStatus &&
                  !completionPending &&
                  widget.requestId != null &&
                  (requestCancelled ||
                      (!waitingForArrivalConfirmation && repairReady)),
              busy: updatingStatus,
              onTap: requestCancelled
                  ? () {
                      replace(context, const ProviderShell());
                    }
                  : advanceStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _RaProviderActiveStatusCard extends StatelessWidget {
  const _RaProviderActiveStatusCard({
    required this.title,
    required this.description,
    required this.status,
    required this.cancelled,
  });

  final String title;
  final String description;
  final int status;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    return RaProviderSummaryCard(
      title: title,
      message: description,
      icon: cancelled ? Icons.cancel_outlined : Icons.route_outlined,
      footer: cancelled ? null : RaProviderJobProgress(current: status),
    );
  }
}

class _RaProviderActiveMap extends StatelessWidget {
  const _RaProviderActiveMap({
    required this.latitude,
    required this.longitude,
    required this.providerPosition,
    required this.roadRoute,
    required this.locationMessage,
    required this.location,
  });

  final double latitude;
  final double longitude;

  final LatLng? providerPosition;
  final RoadRoute? roadRoute;

  final String? locationMessage;
  final String location;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .45),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: MapMock(
                  position: LatLng(latitude, longitude),
                  providerPosition: providerPosition,
                  routePoints: roadRoute?.points,
                  showProviders: providerPosition != null,
                  showRoute: roadRoute != null && providerPosition != null,
                ),
              ),

              if (roadRoute != null)
                Positioned(
                  top: 11,
                  left: 11,
                  right: 11,
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.route_outlined, size: 17),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${roadRoute!.distanceKm.toStringAsFixed(1)} km • ${roadRoute!.durationMinutes} min',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              openMapNavigation(
                context,
                latitude: latitude,
                longitude: longitude,
              );
            },
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Navigate to Driver'),
          ),
        ),

        if (locationMessage != null) ...[
          const SizedBox(height: 8),
          _RaProviderActiveNotice(
            icon: Icons.gps_off_outlined,
            title: 'Location update',
            message: locationMessage!,
            tone: raGold,
          ),
        ],
      ],
    );
  }
}

class _RaProviderActiveDriverCard extends StatelessWidget {
  const _RaProviderActiveDriverCard({
    required this.name,
    required this.phone,
    required this.requestId,
  });

  final String name;
  final String phone;
  final String? requestId;

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
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileInitials(name: name, radius: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.trim().isEmpty ? 'Phone unavailable' : phone,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone.trim().isEmpty
                      ? null
                      : () {
                          showCallPrompt(context, name: name, number: phone);
                        },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: requestId == null
                      ? null
                      : () {
                          push(
                            context,
                            ChatScreen(
                              requestId: requestId,
                              peerName: name,
                              peerPhone: phone,
                            ),
                          );
                        },
                  icon: _UnreadChatIcon(
                    requestId: requestId,
                    seenField: 'providerMessagesSeenAt',
                  ),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaProviderActiveSummary extends StatelessWidget {
  const _RaProviderActiveSummary({
    required this.issue,
    required this.vehicle,
    required this.location,
    required this.approvedTotal,
  });

  final String issue;
  final String vehicle;
  final String location;
  final int? approvedTotal;

  @override
  Widget build(BuildContext context) {
    return _RaProviderActiveSurface(
      child: Column(
        children: [
          _RaProviderActiveInfo(
            icon: Icons.car_repair_outlined,
            label: 'Assistance',
            value: issue,
          ),
          if (vehicle.isNotEmpty) ...[
            const _RaProviderActiveDivider(),
            _RaProviderActiveInfo(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle',
              value: vehicle,
            ),
          ],
          const _RaProviderActiveDivider(),
          _RaProviderActiveInfo(
            icon: Icons.location_on_outlined,
            label: 'Breakdown location',
            value: location,
          ),
          const _RaProviderActiveDivider(),
          _RaProviderActiveInfo(
            icon: Icons.request_quote_outlined,
            label: 'Driver-approved total',
            value: approvedTotal == null
                ? 'Price pending'
                : 'Rs. $approvedTotal',
          ),
        ],
      ),
    );
  }
}

class _RaProviderDocumentationCard extends StatelessWidget {
  const _RaProviderDocumentationCard({
    required this.controller,
    required this.photos,
    required this.saving,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onSave,
  });

  final TextEditingController controller;
  final List<String> photos;

  final bool saving;

  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _RaProviderActiveSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Service notes',
              hintText:
                  'Work completed, observations or important information...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 52),
                child: Icon(Icons.note_alt_outlined),
              ),
            ),
          ),

          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),

            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(
                          base64Decode(photos[index]),
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 94,
                              height: 94,
                              color: colors.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                      ),

                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filled(
                          onPressed: saving
                              ? null
                              : () {
                                  onRemovePhoto(index);
                                },
                          style: IconButton.styleFrom(
                            minimumSize: const Size(30, 30),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.black54,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 15),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 11),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving || photos.length >= 3 ? null : onAddPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    photos.length >= 3 ? '3 Photos Added' : 'Add Photo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaProviderActiveHeading extends StatelessWidget {
  const _RaProviderActiveHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaProviderActiveNotice extends StatelessWidget {
  const _RaProviderActiveNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
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

class _RaProviderActiveSurface extends StatelessWidget {
  const _RaProviderActiveSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: RaProviderCard(child: child),
    );
  }
}

class _RaProviderActiveInfo extends StatelessWidget {
  const _RaProviderActiveInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _RaProviderActiveDivider extends StatelessWidget {
  const _RaProviderActiveDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 47,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: .35),
    );
  }
}

class _RaProviderActiveBottomBar extends StatelessWidget {
  const _RaProviderActiveBottomBar({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled && !busy ? onTap : null,
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
