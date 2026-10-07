part of '../../screens.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.draft,
  });

  final RequestDraft draft;

  @override
  State<ReviewScreen> createState() =>
      _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool submitting = false;

  StreamSubscription<
          List<ConnectivityResult>>?
      connectivitySubscription;

  @override
  void initState() {
    super.initState();

    connectivitySubscription =
        Connectivity()
            .onConnectivityChanged
            .listen(
      (results) async {
        if (!mounted ||
            results.every(
              (result) =>
                  result ==
                  ConnectivityResult
                      .none,
            )) {
          return;
        }

        if (await RequestDraftStore()
                .hasPendingSubmission() &&
            mounted) {
          await submitRequest(
            autoRetry: true,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    connectivitySubscription
        ?.cancel();

    super.dispose();
  }

  bool get readyToSubmit =>
      widget.draft.modelYear
          .trim()
          .isNotEmpty &&
      widget.draft.registration
          .trim()
          .isNotEmpty &&
      !widget.draft.location
          .startsWith(
        'Select current GPS',
      );

  bool get specificProvider =>
      widget.draft
          .preferredProviderId
          .trim()
          .isNotEmpty;

  Future<void> submitRequest({
    bool autoRetry = false,
  }) async {
    if (submitting) return;

    if (!readyToSubmit) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: const Text(
            'Complete every required checklist item before submitting.',
          ),
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
        ),
      );

      return;
    }

    if (FirebaseAuth.instance
            .currentUser ==
        null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in as a driver so providers can receive your request.',
          ),
        ),
      );

      return;
    }

    final connections =
        await Connectivity()
            .checkConnectivity();

    if (connections.every(
      (result) =>
          result ==
          ConnectivityResult.none,
    )) {
      await RequestDraftStore()
          .save(widget.draft);

      await RequestDraftStore()
          .setPendingSubmission(
        true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Your request has been saved and will retry when connected.',
          ),
        ),
      );

      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      final requestId =
          await RequestService()
              .createRequest(
        widget.draft,
      );

      await RequestDraftStore()
          .clear();

      if (!mounted) return;

      await showSafetyChecklist();

      if (!mounted) return;

      replace(
        context,
        SearchingScreen(
          draft: widget.draft,
          requestId: requestId,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final activeRequestExists =
          error.toString().contains(
        'Complete or cancel your active request',
      );

      final networkError =
          error is FirebaseException &&
              const [
                'unavailable',
                'deadline-exceeded',
                'network-request-failed',
              ].contains(
                error.code,
              );

      if (networkError) {
        await RequestDraftStore()
            .save(widget.draft);

        await RequestDraftStore()
            .setPendingSubmission(
          true,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            activeRequestExists
                ? 'Complete or cancel your current request before creating another.'
                : networkError
                    ? 'Connection lost. Your request has been saved and will retry automatically.'
                    : 'Unable to create the request. Please try again.',
          ),
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
          action:
              activeRequestExists
                  ? SnackBarAction(
                      label:
                          'OPEN REQUEST',
                      textColor:
                          Colors.white,
                      onPressed: () =>
                          push(
                        context,
                        const HistoryScreen(),
                      ),
                    )
                  : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  Future<void>
      showSafetyChecklist() async {
    var vehicleSafe = false;
    var hazardsOn = false;
    var passengersSafe = false;
    var emergencyRequired = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                  const EdgeInsets.all(
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
                      const EdgeInsets.all(
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
                            width: 52,
                            height: 52,
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .primaryContainer,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                17,
                              ),
                            ),
                            child: Icon(
                              Icons
                                  .health_and_safety_outlined,
                              color: colors
                                  .onPrimaryContainer,
                              size: 27,
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
                                  'Stay safe while you wait',
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
                                  'Confirm the items that apply to your situation.',
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

                      _RaSafetyCheckTile(
                        icon: Icons
                            .directions_car_outlined,
                        title:
                            'Vehicle is in a safe place',
                        value:
                            vehicleSafe,
                        onChanged: (
                          value,
                        ) {
                          setDialogState(
                            () {
                              vehicleSafe =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            RaSpace.sm,
                      ),

                      _RaSafetyCheckTile(
                        icon: Icons
                            .warning_amber_rounded,
                        title:
                            'Hazard lights are on',
                        value:
                            hazardsOn,
                        onChanged: (
                          value,
                        ) {
                          setDialogState(
                            () {
                              hazardsOn =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            RaSpace.sm,
                      ),

                      _RaSafetyCheckTile(
                        icon: Icons
                            .groups_outlined,
                        title:
                            'Passengers are safe',
                        value:
                            passengersSafe,
                        onChanged: (
                          value,
                        ) {
                          setDialogState(
                            () {
                              passengersSafe =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            RaSpace.sm,
                      ),

                      _RaSafetyCheckTile(
                        icon: Icons
                            .emergency_outlined,
                        title:
                            'Immediate emergency help is required',
                        subtitle:
                            'Use emergency services if there is immediate danger.',
                        danger: true,
                        value:
                            emergencyRequired,
                        onChanged: (
                          value,
                        ) {
                          setDialogState(
                            () {
                              emergencyRequired =
                                  value;
                            },
                          );
                        },
                      ),

                      if (emergencyRequired) ...[
                        const SizedBox(
                          height:
                              RaSpace.md,
                        ),

                        FilledButton.icon(
                          style: FilledButton
                              .styleFrom(
                            backgroundColor:
                                colors
                                    .error,
                            foregroundColor:
                                colors
                                    .onError,
                          ),
                          onPressed: () =>
                              showCallPrompt(
                            dialogContext,
                            name:
                                'Emergency Services',
                            number:
                                '119',
                          ),
                          icon: const Icon(
                            Icons.call_rounded,
                          ),
                          label: const Text(
                            'Call 119',
                          ),
                        ),
                      ],

                      const SizedBox(
                        height:
                            RaSpace.lg,
                      ),

                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(
                          dialogContext,
                        ),
                        icon: const Icon(
                          Icons
                              .navigation_outlined,
                        ),
                        label: const Text(
                          'Continue to Tracking',
                        ),
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
  }

  BreakdownPhotoAnnotation?
      _annotationFor(
    int index,
  ) {
    for (final annotation
        in widget
            .draft.photoAnnotations) {
      if (annotation.photoIndex ==
          index) {
        return annotation;
      }
    }

    return null;
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
                        .looks_4_outlined,
                    size: 16,
                    color: colors
                        .onPrimaryContainer,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    'STEP 4 OF 4',
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
              'Review',
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
            value: 1,
            minHeight: 6,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildHero(
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
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            colors.primary,
            const Color(
              0xFF007D70,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -30,
            child: Icon(
              Icons
                  .task_alt_rounded,
              size: 140,
              color: Colors.white
                  .withValues(
                alpha: .07,
              ),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(17),
                ),
                child: const Icon(
                  Icons
                      .fact_check_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              Text(
                'Review before requesting help',
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
                height: 6,
              ),

              Text(
                'Check your vehicle, location and service details before sending the request to providers.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: Colors.white
                      .withValues(
                    alpha: .84,
                  ),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPreference(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final title = specificProvider
        ? widget.draft.provider
        : 'Receive provider offers';

    final subtitle = specificProvider
        ? 'Your request will be directed toward this selected provider.'
        : 'Suitable providers can review the request and submit offers for you to compare.';

    return _RaReviewCard(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          specificProvider
              ? ProfileInitials(
                  name:
                      widget.draft.provider,
                  radius: 27,
                )
              : Container(
                  width: 54,
                  height: 54,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .primaryContainer,
                    borderRadius:
                        BorderRadius
                            .circular(17),
                  ),
                  child: Icon(
                    Icons
                        .compare_arrows_rounded,
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
                Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  subtitle,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    height: 1.4,
                  ),
                ),
                const SizedBox(
                  height: RaSpace.sm,
                ),
                StatusPill(
                  label: specificProvider
                      ? 'Selected provider'
                      : 'Compare offers',
                  tone: specificProvider
                      ? RaTone.success
                      : RaTone.info,
                  dot: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestDetails(
    BuildContext context,
  ) {
    return _RaReviewCard(
      child: Column(
        children: [
          _RaReviewDetailRow(
            icon:
                Icons.car_repair_outlined,
            label:
                'Assistance',
            value:
                widget.draft.issue,
          ),

          const _RaReviewDivider(),

          _RaReviewDetailRow(
            icon:
                Icons.priority_high_rounded,
            label:
                'Priority',
            value:
                requestPriorityLabel(
              widget.draft.priority,
            ),
          ),

          const _RaReviewDivider(),

          _RaReviewDetailRow(
            icon:
                Icons.directions_car_outlined,
            label:
                'Vehicle',
            value:
                '${widget.draft.modelYear} • ${widget.draft.vehicleType}',
          ),

          const _RaReviewDivider(),

          _RaReviewDetailRow(
            icon:
                Icons.pin_outlined,
            label:
                'Registration',
            value: widget
                .draft.registration
                .toUpperCase(),
          ),

          const _RaReviewDivider(),

          _RaReviewDetailRow(
            icon:
                Icons.location_on_outlined,
            label:
                'Pickup location',
            value:
                widget.draft.location,
          ),

          if (widget.draft.landmark
              .isNotEmpty) ...[
            const _RaReviewDivider(),
            _RaReviewDetailRow(
              icon:
                  Icons.signpost_outlined,
              label:
                  'Landmark',
              value:
                  widget.draft.landmark,
            ),
          ],

          if (widget.draft.description
              .trim()
              .isNotEmpty) ...[
            const _RaReviewDivider(),
            _RaReviewDetailRow(
              icon:
                  Icons.description_outlined,
              label:
                  'Symptoms',
              value:
                  widget.draft.description,
            ),
          ],

          const _RaReviewDivider(),

          _RaReviewDetailRow(
            icon:
                Icons.settings_outlined,
            label:
                'Parts preference',
            value:
                _partsPreferenceLabel(
              widget
                  .draft.partsPreference,
            ),
          ),
        ],
      ),
    );
  }

  String _partsPreferenceLabel(
    String value,
  ) {
    return switch (value) {
      'budget' =>
        'Budget compatible',
      'branded' =>
        'Branded aftermarket',
      'genuine' =>
        'Genuine manufacturer parts',
      _ =>
        'Discuss options with provider',
    };
  }

  Widget _buildEvidence(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    if (widget
        .draft.vehiclePhotoUrls.isEmpty) {
      return _RaReviewCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color: colors
                    .surfaceContainerHighest,
                borderRadius:
                    BorderRadius
                        .circular(14),
              ),
              child: Icon(
                Icons
                    .photo_outlined,
                color: colors
                    .onSurfaceVariant,
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
                    'No photo evidence',
                    style: theme
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    'Photos are optional and can help providers understand visible damage.',
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _RaReviewCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 105,
            child:
                ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount: widget
                  .draft
                  .vehiclePhotoUrls
                  .length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: RaSpace.sm,
              ),
              itemBuilder:
                  (context, index) {
                final annotation =
                    _annotationFor(
                  index,
                );

                Widget photo;

                try {
                  photo =
                      Image.memory(
                    base64Decode(
                      widget.draft
                              .vehiclePhotoUrls[
                          index],
                    ),
                    width: 105,
                    height: 105,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                      _,
                      __,
                      ___,
                    ) {
                      return Container(
                        color: colors
                            .surfaceContainerHighest,
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
                      Icons
                          .broken_image_outlined,
                    ),
                  );
                }

                return SizedBox(
                  width: 105,
                  height: 105,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                          child:
                              photo,
                        ),
                      ),
                      if (annotation !=
                          null)
                        Positioned(
                          left: annotation
                                      .markerX *
                                  88 -
                              2,
                          top: annotation
                                      .markerY *
                                  82 -
                              7,
                          child: Icon(
                            Icons
                                .location_on_rounded,
                            color: colors
                                .error,
                            size: 25,
                            shadows:
                                const [
                              Shadow(
                                color:
                                    Colors.white,
                                blurRadius:
                                    4,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          for (final annotation
              in widget
                  .draft
                  .photoAnnotations)
            if (annotation.note
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: RaSpace.sm,
              ),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Icon(
                    Icons
                        .location_on_outlined,
                    size: 17,
                    color:
                        colors.error,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child: Text(
                      'Photo ${annotation.photoIndex + 1}: ${annotation.note}',
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
    );
  }

  Widget _buildPricingInfo(
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
        color: colors
            .secondaryContainer
            .withValues(alpha: .32),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.secondary
              .withValues(alpha: .15),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                      .request_quote_outlined,
                  color: colors
                      .onSecondaryContainer,
                ),
              ),
              const SizedBox(
                width: RaSpace.md,
              ),
              Expanded(
                child: Text(
                  'Pricing comes before assignment',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          const _RaPricingPoint(
            text:
                'Providers review your vehicle and symptoms before quoting.',
          ),
          const _RaPricingPoint(
            text:
                'Service, travel and other charges are shown separately.',
          ),
          const _RaPricingPoint(
            text:
                'You approve an offer before the provider is assigned.',
          ),
          const _RaPricingPoint(
            text:
                'Additional work or price changes require another approval.',
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
          'Review Request',
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

                  _buildHero(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _RaReviewSectionTitle(
                    title:
                        'Provider preference',
                    subtitle:
                        'How your request will be sent.',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildProviderPreference(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _RaReviewSectionTitle(
                    title:
                        'Request details',
                    subtitle:
                        'Confirm the information providers will receive.',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildRequestDetails(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _RaReviewSectionTitle(
                    title:
                        'Ready to submit',
                    subtitle:
                        'Required information check.',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _RequestValidationChecklist(
                    draft:
                        widget.draft,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _RaReviewSectionTitle(
                    title:
                        'Photo evidence',
                    subtitle:
                        'Images attached to this request.',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildEvidence(
                    context,
                  ),

                  const SizedBox(
                    height:
                        RaSpace.xxl,
                  ),

                  const _RaReviewSectionTitle(
                    title:
                        'Pricing & approval',
                    subtitle:
                        'No repair price is accepted at this stage.',
                  ),

                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),

                  _buildPricingInfo(
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
                          .surfaceContainerHighest
                          .withValues(
                        alpha: .42,
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
                              .chat_bubble_outline_rounded,
                          size: 19,
                          color: colors
                              .primary,
                        ),
                        const SizedBox(
                          width:
                              RaSpace.sm,
                        ),
                        Expanded(
                          child: Text(
                            'Chat, calling and tracking become available as the assistance workflow progresses.',
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

            _RaReviewBottomBar(
              submitting:
                  submitting,
              enabled:
                  readyToSubmit &&
                      !submitting,
              onSubmit: () =>
                  submitRequest(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaReviewCard
    extends StatelessWidget {
  const _RaReviewCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: child,
    );
  }
}

class _RaReviewSectionTitle
    extends StatelessWidget {
  const _RaReviewSectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme
              .textTheme.titleLarge
              ?.copyWith(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme
              .textTheme.bodySmall
              ?.copyWith(
            color: colors
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaReviewDetailRow
    extends StatelessWidget {
  const _RaReviewDetailRow({
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
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: .7),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: colors.primary,
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
                    height: 1.4,
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

class _RaReviewDivider
    extends StatelessWidget {
  const _RaReviewDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 50,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(alpha: .5),
    );
  }
}

class _RaPricingPoint
    extends StatelessWidget {
  const _RaPricingPoint({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: RaSpace.sm,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons
                .check_circle_outline_rounded,
            color: raSuccess,
            size: 18,
          ),
          const SizedBox(
            width: RaSpace.sm,
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaSafetyCheckTile
    extends StatelessWidget {
  const _RaSafetyCheckTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool danger;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final tone =
        danger
            ? colors.error
            : colors.primary;

    return Material(
      color: value
          ? tone.withValues(
              alpha: .08,
            )
          : colors
              .surfaceContainerHighest
              .withValues(alpha: .36),
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: () =>
            onChanged(!value),
        borderRadius:
            BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(13),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 20,
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
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    if (subtitle !=
                        null) ...[
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        subtitle!,
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              Checkbox(
                value: value,
                onChanged: (newValue) =>
                    onChanged(
                  newValue ?? false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaReviewBottomBar
    extends StatelessWidget {
  const _RaReviewBottomBar({
    required this.submitting,
    required this.enabled,
    required this.onSubmit,
  });

  final bool submitting;
  final bool enabled;
  final VoidCallback onSubmit;

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
            onPressed:
                enabled
                    ? onSubmit
                    : null,
            icon: submitting
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .send_rounded,
                  ),
            label: Text(
              submitting
                  ? 'Submitting Request…'
                  : 'Confirm Assistance Request',
            ),
          ),
        ),
      ),
    );
  }
}