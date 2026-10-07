part of '../../screens.dart';

class ProviderActiveJobScreen
    extends StatefulWidget {
  const ProviderActiveJobScreen({
    super.key,
    this.requestId,
    this.requestData = const {},
  });

  final String? requestId;

  final Map<String, dynamic>
      requestData;

  @override
  State<ProviderActiveJobScreen>
      createState() =>
          _ProviderActiveJobScreenState();
}

class _ProviderActiveJobScreenState
    extends State<ProviderActiveJobScreen> {
  int status = 0;

  final statuses = const [
    'Accepted',
    'En Route',
    'Arrived',
    'Completed',
  ];

  static const backendStatuses = [
    'accepted',
    'en_route',
    'arrived',
    'completed',
  ];

  StreamSubscription<Position>?
      locationSubscription;

  StreamSubscription<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      requestSubscription;

  late Map<String, dynamic>
      requestData;

  bool updatingStatus = false;
  bool requestCancelled = false;

  String? locationMessage;

  LatLng? currentProviderPosition;

  RoadRoute? roadRoute;

  int routeRequestVersion = 0;

  final serviceNotesController =
      TextEditingController();

  List<String> servicePhotos =
      <String>[];

  bool savingDocumentation =
      false;

  @override
  void initState() {
    super.initState();

    requestData =
        Map<String, dynamic>.from(
      widget.requestData,
    );

    status =
        backendStatuses.indexOf(
      requestData['status']
              as String? ??
          'accepted',
    );

    if (status < 0) {
      status = 0;
    }

    requestCancelled =
        requestData['status'] ==
            'cancelled';

    serviceNotesController.text =
        requestData['serviceNotes']
                as String? ??
            '';

    servicePhotos =
        (requestData[
                        'servicePhotoData']
                    as List<dynamic>? ??
                const [])
            .whereType<String>()
            .toList();

    if (widget.requestId != null) {
      requestSubscription =
          RequestService()
              .watchRequest(
                widget.requestId!,
              )
              .listen(
        (snapshot) {
          final data =
              snapshot.data();

          if (!mounted ||
              data == null) {
            return;
          }

          final nextStatus =
              backendStatuses
                  .indexOf(
            data['status']
                    as String? ??
                '',
          );

          setState(() {
            requestData = data;

            requestCancelled =
                data['status'] ==
                    'cancelled';

            if (nextStatus >= 0) {
              status =
                  nextStatus;
            }

            servicePhotos =
                (data['servicePhotoData']
                            as List<
                                dynamic>? ??
                        const [])
                    .whereType<
                        String>()
                    .toList();
          });
        },
        onError: (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to receive live request updates.',
              ),
            ),
          );
        },
      );
    }

    startLocationSharing();
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    requestSubscription?.cancel();
    serviceNotesController
        .dispose();

    super.dispose();
  }

  Future<void> startLocationSharing() async {
    if (widget.requestId ==
        null) {
      return;
    }

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
            LocationPermission
                .denied ||
        permission ==
            LocationPermission
                .deniedForever) {
      if (mounted) {
        setState(() {
          locationMessage =
              'Location permission is required to share your live position.';
        });
      }
      return;
    }

    locationSubscription =
        Geolocator
            .getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen(
      (position) {
        final point = LatLng(
          position.latitude,
          position.longitude,
        );

        if (mounted) {
          setState(() {
            currentProviderPosition =
                point;

            locationMessage = null;
          });
        }

        unawaited(
          refreshProviderRoute(
            point,
          ),
        );

        RequestService()
            .updateProviderLocation(
          widget.requestId!,
          latitude:
              position.latitude,
          longitude:
              position.longitude,
        );
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          locationMessage =
              'Live location sharing stopped.';
        });
      },
    );
  }

  Future<void> refreshProviderRoute(
    LatLng origin,
  ) async {
    final latitude =
        (requestData['latitude']
                as num?)
            ?.toDouble();

    final longitude =
        (requestData['longitude']
                as num?)
            ?.toDouble();

    if (latitude == null ||
        longitude == null) {
      return;
    }

    final version =
        ++routeRequestVersion;

    try {
      final result =
          await const RouteService()
              .fetchDrivingRoute(
        origin: origin,
        destination: LatLng(
          latitude,
          longitude,
        ),
      );

      if (!mounted ||
          version !=
              routeRequestVersion) {
        return;
      }

      setState(() {
        roadRoute = result;
      });
    } catch (_) {
      if (!mounted ||
          version !=
              routeRequestVersion) {
        return;
      }

      setState(() {
        locationMessage =
            'Road route ETA is unavailable.';
      });
    }
  }

  Future<void> withdraw() async {
    final reason =
        await _adminReason(
      context,
      'Why can you no longer attend this job?',
    );

    if (reason == null ||
        !mounted ||
        widget.requestId == null) {
      return;
    }

    setState(() {
      updatingStatus = true;
    });

    try {
      await RequestService()
          .withdrawProvider(
        widget.requestId!,
        reason,
      );

      if (mounted) {
        replace(
          context,
          const ProviderShell(),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('$error'),
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

  Future<void>
      addDocumentationPhoto() async {
    if (servicePhotos.length >=
            3 ||
        widget.requestId == null) {
      return;
    }

    final navigator =
        Navigator.of(context);

    final source =
        await showModalBottomSheet<
            ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return const SafeArea(
          child: Wrap(
            children: [
              _PhotoSourceTile(
                icon: Icons
                    .camera_alt_outlined,
                label:
                    'Take a photo',
                source:
                    ImageSource.camera,
              ),
              _PhotoSourceTile(
                icon: Icons
                    .photo_library_outlined,
                label:
                    'Choose from gallery',
                source:
                    ImageSource.gallery,
              ),
            ],
          ),
        );
      },
    );

    if (source == null ||
        !mounted) {
      return;
    }

    final photo =
        source ==
                ImageSource.camera
            ? await navigator
                .push<XFile>(
                MaterialPageRoute(
                  builder: (_) =>
                      const CameraCaptureScreen(),
                ),
              )
            : await ImagePicker()
                .pickImage(
                source:
                    ImageSource.gallery,
                imageQuality: 70,
                maxWidth: 1200,
              );

    if (photo == null ||
        !mounted) {
      return;
    }

    setState(() {
      savingDocumentation =
          true;
    });

    try {
      final encoded =
          await PhotoUploadService()
              .prepareVehiclePhoto(
        photo,
      );

      final updated = [
        ...servicePhotos,
        encoded,
      ];

      await RequestService()
          .updateProviderDocumentation(
        widget.requestId!,
        serviceNotes:
            serviceNotesController
                .text,
        servicePhotoData:
            updated,
      );

      if (mounted) {
        setState(() {
          servicePhotos =
              updated;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to add documentation: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingDocumentation =
              false;
        });
      }
    }
  }

  Future<void>
      saveDocumentation() async {
    if (widget.requestId ==
            null ||
        savingDocumentation) {
      return;
    }

    setState(() {
      savingDocumentation =
          true;
    });

    try {
      await RequestService()
          .updateProviderDocumentation(
        widget.requestId!,
        serviceNotes:
            serviceNotesController
                .text,
        servicePhotoData:
            servicePhotos,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Service documentation saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save notes: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingDocumentation =
              false;
        });
      }
    }
  }

  Future<void>
      removeDocumentationPhoto(
    int index,
  ) async {
    if (widget.requestId ==
            null ||
        savingDocumentation) {
      return;
    }

    final updated = [
      ...servicePhotos,
    ]..removeAt(index);

    setState(() {
      servicePhotos = updated;
    });

    try {
      await RequestService()
          .updateProviderDocumentation(
        widget.requestId!,
        serviceNotes:
            serviceNotesController
                .text,
        servicePhotoData:
            updated,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to remove the photo.',
          ),
        ),
      );
    }
  }

  Future<int?>
      requestFinalCost() async {
    final approved =
        (requestData[
                    'estimatedCost']
                as num?)
            ?.toInt() ??
        0;

    final protected =
        requestData[
                'workflowVersion'] ==
            2;

    final controller =
        TextEditingController(
      text: '$approved',
    );

    final costRoute =
        DialogRoute<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            refresh,
          ) {
            final amount =
                int.tryParse(
              controller.text,
            );

            final changed =
                protected &&
                    amount !=
                        approved;

            return AlertDialog(
              icon: const Icon(
                Icons
                    .receipt_long_outlined,
              ),
              title: const Text(
                'Confirm final charge',
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .all(
                      RaSpace.md,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primaryContainer
                          .withValues(
                        alpha: .32,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: Text(
                      'Driver-approved total: Rs. $approved',
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  TextField(
                    controller:
                        controller,
                    autofocus: true,
                    keyboardType:
                        TextInputType
                            .number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                      LengthLimitingTextInputFormatter(
                        8,
                      ),
                    ],
                    onChanged: (_) =>
                        refresh(
                      () {},
                    ),
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Final amount (Rs.)',
                      prefixIcon:
                          Icon(
                        Icons
                            .payments_outlined,
                      ),
                    ),
                  ),

                  if (changed) ...[
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),
                    const InlineMessage(
                      icon: Icons
                          .approval_outlined,
                      text:
                          'A changed price needs a reason and driver approval. An increase also needs photo evidence. The job remains open while approval is pending.',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    dialogContext,
                  ),
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed:
                      amount == null ||
                              amount <
                                  0 ||
                              amount >
                                  10000000
                          ? null
                          : () =>
                              Navigator.pop(
                                dialogContext,
                                amount,
                              ),
                  child: Text(
                    changed
                        ? 'Request Approval'
                        : 'Complete Job',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final value =
        await Navigator.of(
      context,
      rootNavigator: true,
    ).push(costRoute);

    await costRoute.completed;

    controller.dispose();

    if (value == null ||
        !mounted) {
      return null;
    }

    if (protected &&
        value != approved) {
      final quote =
          await requestProviderQuote(
        context,
        {
          ...requestData,
          'repairRevision':
              true,
          'proposedTotal':
              value,
        },
      );

      if (quote == null ||
          !mounted) {
        return null;
      }

      try {
        await RequestService()
            .proposeRepair(
          widget.requestId!,
          quote,
        );

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Price change sent. Wait for driver approval, then complete the job at the approved total.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Could not send the price change. Check access, connection and whether another change is pending.',
              ),
            ),
          );
        }
      }

      return null;
    }

    return value;
  }

  Future<void> advanceStatus() async {
    if (updatingStatus ||
        widget.requestId == null ||
        requestCancelled) {
      return;
    }

    if (status == 3) {
      replace(
        context,
        ProviderCompletedScreen(
          requestId:
              widget.requestId!,
          requestData:
              requestData,
        ),
      );

      return;
    }

    int? finalCost;

    if (status == 2) {
      finalCost =
          await requestFinalCost();

      if (finalCost == null ||
          !mounted) {
        return;
      }
    }

    setState(() {
      updatingStatus = true;
    });

    try {
      if (status == 2) {
        await RequestService()
            .updateProviderDocumentation(
          widget.requestId!,
          serviceNotes:
              serviceNotesController
                  .text,
          servicePhotoData:
              servicePhotos,
        );

        await RequestService()
            .completeProviderJob(
          widget.requestId!,
          finalCost!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Completion submitted. Waiting for driver confirmation.',
              ),
            ),
          );
        }
      } else {
        await RequestService()
            .advanceProviderStatus(
          widget.requestId!,
          backendStatuses[
              status + 1],
        );

        try {
          await RequestService()
              .updateProviderDocumentation(
            widget.requestId!,
            serviceNotes:
                serviceNotesController
                    .text,
            servicePhotoData:
                servicePhotos,
          );
        } catch (_) {
          // Optional notes must not
          // block job progression.
        }
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

  String get _statusMessage {
    if (requestCancelled) {
      return 'The driver cancelled this assistance request.';
    }

    return switch (status) {
      0 =>
        'Prepare for the job and start travelling when ready.',
      1 =>
        'Your live location is being shared while you travel.',
      2 =>
        'Confirm arrival requirements before beginning work.',
      _ =>
        'The roadside assistance workflow is complete.',
    };
  }

  bool get _canAdvance {
    final data = requestData;

    return !updatingStatus &&
        data['completionState'] !=
            'pending' &&
        (status != 2 ||
            data['arrivalVerificationRequired'] !=
                true ||
            data['arrivalConfirmedBy'] ==
                data['driverId']) &&
        widget.requestId != null &&
        (requestCancelled ||
            status != 2 ||
            data['workflowVersion'] !=
                2 ||
            (data['pendingRepairId'] ==
                    null &&
                (data['approvedQuoteType'] !=
                        'inspection' ||
                    data['approvedRepairId'] !=
                        null)));
  }

  String get _actionLabel {
    final data = requestData;

    if (updatingStatus) {
      return 'Updating status…';
    }

    if (data['completionState'] ==
        'pending') {
      return 'Waiting for Driver Confirmation';
    }

    if (requestCancelled) {
      return 'Back to Dashboard';
    }

    if (status == 3) {
      return 'Finish Job';
    }

    return 'Mark as ${statuses[status + 1]}';
  }

  IconData get _statusIcon {
    return switch (status) {
      0 =>
        Icons.handshake_outlined,
      1 =>
        Icons.navigation_outlined,
      2 =>
        Icons
            .location_on_outlined,
      _ =>
        Icons.task_alt_rounded,
    };
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final data = requestData;

    final latitude =
        (data['latitude'] as num?)
            ?.toDouble();

    final longitude =
        (data['longitude'] as num?)
            ?.toDouble();

    final hasDestination =
        latitude != null &&
            longitude != null;

    final driverName =
        data['driverName']
                as String? ??
            'Driver';

    final driverPhone =
        data['driverPhone']
                as String? ??
            '';

    final vehicle = [
      data['vehicleType']
              as String? ??
          '',
      data['modelYear']
              as String? ??
          '',
      data['registration']
              as String? ??
          '',
    ]
        .where(
          (value) =>
              value.isNotEmpty,
        )
        .join(' • ');

    return Scaffold(
      backgroundColor:
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Active Assistance',
        ),
        actions: [
          if (widget.requestId !=
              null)
            IconButton(
              tooltip:
                  'Job details',
              onPressed: () =>
                  push(
                context,
                ProviderRequestDetailsScreen(
                  requestId:
                      widget.requestId!,
                  data: data,
                ),
              ),
              icon: const Icon(
                Icons
                    .description_outlined,
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
                  RaSpace.md,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  if (widget.requestId !=
                          null &&
                      (data['arrivalVerificationRequired'] !=
                              true ||
                          data['arrivalConfirmedBy'] ==
                              data['driverId'])) ...[
                    RepairQuotePanel(
                      requestId:
                          widget
                              .requestId!,
                      isProvider:
                          true,
                    ),
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),
                  ],

                  Container(
                    padding:
                        const EdgeInsets
                            .all(
                      RaSpace.xl,
                    ),
                    decoration:
                        BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment
                                .topLeft,
                        end:
                            Alignment
                                .bottomRight,
                        colors:
                            requestCancelled
                                ? [
                                    colors.error,
                                    const Color(
                                      0xFF9B2922,
                                    ),
                                  ]
                                : [
                                    colors.primary,
                                    const Color(
                                      0xFF007D70,
                                    ),
                                  ],
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        24,
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
                              width: 46,
                              height: 46,
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .white
                                    .withValues(
                                  alpha:
                                      .14,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  15,
                                ),
                              ),
                              child:
                                  Icon(
                                requestCancelled
                                    ? Icons
                                        .close_rounded
                                    : _statusIcon,
                                color: Colors
                                    .white,
                              ),
                            ),
                            const SizedBox(
                              width:
                                  RaSpace
                                      .md,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requestCancelled
                                        ? 'Request Cancelled'
                                        : statuses[status],
                                    style: theme
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                      color:
                                          Colors.white,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        3,
                                  ),
                                  Text(
                                    _statusMessage,
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: Colors
                                          .white
                                          .withValues(
                                        alpha:
                                            .82,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (!requestCancelled) ...[
                          const SizedBox(
                            height:
                                RaSpace
                                    .lg,
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
                                  .surface,
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child:
                                StatusTimeline(
                              statuses:
                                  statuses,
                              current:
                                  status,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (hasDestination) ...[
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    Container(
                      height: 280,
                      clipBehavior:
                          Clip.antiAlias,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          22,
                        ),
                        border:
                            Border.all(
                          color: colors
                              .outlineVariant
                              .withValues(
                            alpha:
                                .6,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child:
                                MapMock(
                              position:
                                  LatLng(
                                latitude,
                                longitude,
                              ),
                              providerPosition:
                                  currentProviderPosition,
                              routePoints:
                                  roadRoute
                                      ?.points,
                              showProviders:
                                  currentProviderPosition !=
                                      null,
                              showRoute:
                                  roadRoute !=
                                      null,
                            ),
                          ),

                          Positioned(
                            top:
                                RaSpace.md,
                            left:
                                RaSpace.md,
                            right:
                                RaSpace.md,
                            child:
                                Container(
                              padding:
                                  const EdgeInsets
                                      .all(
                                RaSpace
                                    .md,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: colors
                                    .surface
                                    .withValues(
                                  alpha:
                                      .94,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  15,
                                ),
                              ),
                              child:
                                  Row(
                                children: [
                                  Icon(
                                    currentProviderPosition ==
                                            null
                                        ? Icons
                                            .location_searching_rounded
                                        : Icons
                                            .share_location_outlined,
                                    color: colors
                                        .primary,
                                  ),
                                  const SizedBox(
                                    width:
                                        RaSpace.sm,
                                  ),
                                  Expanded(
                                    child:
                                        Text(
                                      currentProviderPosition ==
                                              null
                                          ? 'Finding your live location…'
                                          : roadRoute ==
                                                  null
                                              ? 'Live location sharing active'
                                              : '${roadRoute!.distanceKm.toStringAsFixed(1)} km • ${roadRoute!.durationMinutes} min',
                                      style: theme
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
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

                    const SizedBox(
                      height:
                          RaSpace.sm,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: () =>
                            openMapNavigation(
                          context,
                          latitude:
                              latitude,
                          longitude:
                              longitude,
                        ),
                        icon: const Icon(
                          Icons
                              .navigation_outlined,
                        ),
                        label: const Text(
                          'Open Navigation',
                        ),
                      ),
                    ),
                  ],

                  if (locationMessage !=
                      null) ...[
                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),
                    InlineMessage(
                      icon: Icons
                          .location_off_outlined,
                      text:
                          locationMessage!,
                    ),
                  ],

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  Text(
                    'Customer & job',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
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
                      RaSpace.lg,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          colors.surface,
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                      border:
                          Border.all(
                        color: colors
                            .outlineVariant
                            .withValues(
                          alpha: .6,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ProfileInitials(
                              name:
                                  driverName,
                              radius: 25,
                            ),
                            const SizedBox(
                              width:
                                  RaSpace.md,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driverName,
                                    style: theme
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        2,
                                  ),
                                  Text(
                                    requestIssueLabel(
                                      data,
                                    ),
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
                              RaSpace.md,
                        ),

                        _ProviderActiveInfoRow(
                          icon: Icons
                              .directions_car_outlined,
                          label:
                              'Vehicle',
                          value: vehicle
                                  .isEmpty
                              ? 'Vehicle details unavailable'
                              : vehicle,
                        ),

                        const SizedBox(
                          height:
                              RaSpace.sm,
                        ),

                        _ProviderActiveInfoRow(
                          icon: Icons
                              .location_on_outlined,
                          label:
                              'Breakdown location',
                          value:
                              data['locationLabel']
                                      as String? ??
                                  'Pinned location',
                        ),

                        const SizedBox(
                          height:
                              RaSpace.md,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed:
                                    driverPhone
                                            .isEmpty
                                        ? null
                                        : () =>
                                            showCallPrompt(
                                              context,
                                              name:
                                                  driverName,
                                              number:
                                                  driverPhone,
                                            ),
                                icon:
                                    const Icon(
                                  Icons
                                      .call_outlined,
                                ),
                                label:
                                    const Text(
                                  'Call',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width:
                                  RaSpace.sm,
                            ),
                            Expanded(
                              child:
                                  FilledButton.icon(
                                onPressed:
                                    widget.requestId ==
                                            null
                                        ? null
                                        : () =>
                                            push(
                                              context,
                                              ChatScreen(
                                                requestId:
                                                    widget.requestId,
                                                peerName:
                                                    driverName,
                                                peerPhone:
                                                    driverPhone,
                                              ),
                                            ),
                                icon:
                                    _UnreadChatIcon(
                                  requestId:
                                      widget.requestId,
                                  seenField:
                                      'providerMessagesSeenAt',
                                ),
                                label:
                                    const Text(
                                  'Message',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (requestCancelled) ...[
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
                            .errorContainer
                            .withValues(
                          alpha: .4,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .cancel_outlined,
                            color:
                                colors.error,
                          ),
                          const SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          const Expanded(
                            child: Text(
                              'The driver cancelled this assistance request.',
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

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Service documentation',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height:
                                  3,
                            ),
                            Text(
                              'Add notes and photos documenting the work performed.',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${servicePhotos.length}/3',
                        style: theme
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                          color:
                              colors.primary,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .all(
                      RaSpace.lg,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          colors.surface,
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                      border:
                          Border.all(
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
                        SizedBox(
                          height: 105,
                          child:
                              ListView(
                            scrollDirection:
                                Axis.horizontal,
                            children: [
                              if (servicePhotos
                                      .length <
                                  3)
                                InkWell(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    15,
                                  ),
                                  onTap:
                                      savingDocumentation
                                          ? null
                                          : addDocumentationPhoto,
                                  child:
                                      Container(
                                    width: 96,
                                    decoration:
                                        BoxDecoration(
                                      color: colors
                                          .primaryContainer
                                          .withValues(
                                        alpha:
                                            .30,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        15,
                                      ),
                                      border:
                                          Border.all(
                                        color: colors
                                            .primary
                                            .withValues(
                                          alpha:
                                              .32,
                                        ),
                                      ),
                                    ),
                                    child:
                                        Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        savingDocumentation
                                            ? const SizedBox.square(
                                                dimension:
                                                    22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth:
                                                      2,
                                                ),
                                              )
                                            : Icon(
                                                Icons.add_a_photo_outlined,
                                                color:
                                                    colors.primary,
                                              ),
                                        const SizedBox(
                                          height:
                                              6,
                                        ),
                                        const Text(
                                          'Add Photo',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              for (var index =
                                      0;
                                  index <
                                      servicePhotos
                                          .length;
                                  index++) ...[
                                const SizedBox(
                                  width:
                                      RaSpace.sm,
                                ),
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                        15,
                                      ),
                                      child:
                                          Image.memory(
                                        base64Decode(
                                          servicePhotos[
                                              index],
                                        ),
                                        width:
                                            122,
                                        height:
                                            105,
                                        fit: BoxFit
                                            .cover,
                                      ),
                                    ),
                                    Positioned(
                                      top:
                                          4,
                                      right:
                                          4,
                                      child:
                                          IconButton.filled(
                                        style:
                                            IconButton.styleFrom(
                                          minimumSize:
                                              const Size(
                                            28,
                                            28,
                                          ),
                                          padding:
                                              EdgeInsets.zero,
                                          backgroundColor:
                                              Colors.black54,
                                          foregroundColor:
                                              Colors.white,
                                        ),
                                        onPressed: () =>
                                            removeDocumentationPhoto(
                                          index,
                                        ),
                                        icon:
                                            const Icon(
                                          Icons.close_rounded,
                                          size:
                                              16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(
                          height:
                              RaSpace.lg,
                        ),

                        TextField(
                          controller:
                              serviceNotesController,
                          enabled:
                              data['completionState'] !=
                                  'pending',
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          textCapitalization:
                              TextCapitalization
                                  .sentences,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Service notes',
                            hintText:
                                'Arrival notes, diagnosis, work completed or important observations...',
                            alignLabelWithHint:
                                true,
                            prefixIcon:
                                Padding(
                              padding:
                                  EdgeInsets.only(
                                bottom:
                                    65,
                              ),
                              child:
                                  Icon(
                                Icons
                                    .note_alt_outlined,
                              ),
                            ),
                          ),
                        ),

                        Align(
                          alignment:
                              Alignment
                                  .centerRight,
                          child:
                              TextButton.icon(
                            onPressed:
                                savingDocumentation ||
                                        data['completionState'] ==
                                            'pending'
                                    ? null
                                    : saveDocumentation,
                            icon: const Icon(
                              Icons
                                  .save_outlined,
                            ),
                            label: const Text(
                              'Save Notes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (status == 2 &&
                      data['arrivalVerificationRequired'] ==
                          true &&
                      data['arrivalConfirmedBy'] ==
                          null) ...[
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
                        color:
                            raGoldPale,
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .hourglass_top_rounded,
                            color:
                                raGold,
                          ),
                          SizedBox(
                            width:
                                RaSpace.sm,
                          ),
                          Expanded(
                            child: Text(
                              'Waiting for driver arrival confirmation. Do not begin repair work until the driver confirms.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (!requestCancelled &&
                      status < 2) ...[
                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),
                    Center(
                      child:
                          TextButton.icon(
                        style:
                            TextButton
                                .styleFrom(
                          foregroundColor:
                              colors.error,
                        ),
                        onPressed:
                            updatingStatus
                                ? null
                                : withdraw,
                        icon: const Icon(
                          Icons
                              .person_off_outlined,
                        ),
                        label: const Text(
                          'Cannot Attend This Job',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            _ProviderJobBottomBar(
              label:
                  _actionLabel,
              enabled:
                  requestCancelled ||
                      _canAdvance,
              loading:
                  updatingStatus,
              onPressed:
                  requestCancelled
                      ? () =>
                          replace(
                            context,
                            const ProviderShell(),
                          )
                      : advanceStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderActiveInfoRow
    extends StatelessWidget {
  const _ProviderActiveInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
        Icon(
          icon,
          size: 18,
          color:
              colors.primary,
        ),
        const SizedBox(
          width: RaSpace.sm,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme
                  .textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: value,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderJobBottomBar
    extends StatelessWidget {
  const _ProviderJobBottomBar({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

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
        child: SizedBox(
          width:
              double.infinity,
          child:
              FilledButton.icon(
            onPressed: enabled
                ? onPressed
                : null,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .arrow_forward_rounded,
                  ),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}