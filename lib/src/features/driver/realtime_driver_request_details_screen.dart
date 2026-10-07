part of '../../screens.dart';

class RealtimeDriverRequestDetailsScreen
    extends StatelessWidget {
  const RealtimeDriverRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  String get status =>
      data['status'] as String? ??
      'searching';

  String get provider =>
      data['providerName']
              as String? ??
          'Not assigned';

  String get providerPhone =>
      data['providerPhone']
              as String? ??
          '';

  bool get providerAssigned =>
      (data['providerId']
                  as String? ??
              '')
          .trim()
          .isNotEmpty;

  int money(
    String key,
  ) {
    return (data[key] as num?)
            ?.toInt() ??
        0;
  }

  String formatMoney(
    int value,
  ) {
    final digits =
        value.abs().toString();

    final buffer =
        StringBuffer();

    for (var index = 0;
        index < digits.length;
        index++) {
      if (index > 0 &&
          (digits.length - index) %
                  3 ==
              0) {
        buffer.write(',');
      }

      buffer.write(
        digits[index],
      );
    }

    return 'Rs. ${value < 0 ? '-' : ''}${buffer.toString()}';
  }

  String statusLabel() {
    return switch (status) {
      'searching' =>
        'Searching',
      'accepted' =>
        'Accepted',
      'en_route' =>
        'En route',
      'arrived' =>
        'Provider arrived',
      'completed' =>
        'Completed',
      'cancelled' =>
        'Cancelled',
      _ =>
        status.replaceAll(
          '_',
          ' ',
        ),
    };
  }

  RaTone statusTone() {
    return switch (status) {
      'completed' =>
        RaTone.success,
      'cancelled' =>
        RaTone.danger,
      'arrived' =>
        RaTone.success,
      _ => RaTone.info,
    };
  }

  int timelineIndex() {
    return switch (status) {
      'accepted' => 0,
      'en_route' => 1,
      'arrived' => 2,
      'completed' => 3,
      _ => 0,
    };
  }

  void showReceipt(
    BuildContext context,
  ) {
    push(
      context,
      InvoiceScreen(
        requestId: requestId,
      ),
    );
  }

  Future<void> rateService(
    BuildContext context,
  ) async {
    var selectedRating =
        (data['driverRating']
                    as num?)
                ?.toInt() ??
            0;

    final rating =
        await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            final theme =
                Theme.of(context);

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
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration:
                          BoxDecoration(
                        color: raGoldPale,
                        borderRadius:
                            BorderRadius
                                .circular(
                          19,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .star_rounded,
                        color: raGold,
                        size: 30,
                      ),
                    ),

                    const SizedBox(
                      height:
                          RaSpace.md,
                    ),

                    Text(
                      'Rate your service',
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
                      height: 4,
                    ),

                    Text(
                      'How was your roadside assistance experience?',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyMedium,
                    ),

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children:
                          List.generate(
                        5,
                        (index) =>
                            IconButton(
                          onPressed: () {
                            setSheetState(
                              () {
                                selectedRating =
                                    index +
                                        1;
                              },
                            );
                          },
                          icon:
                              Icon(
                            index <
                                    selectedRating
                                ? Icons
                                    .star_rounded
                                : Icons
                                    .star_outline_rounded,
                            color:
                                raGold,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                    if (selectedRating >
                        0) ...[
                      const SizedBox(
                        height:
                            RaSpace.sm,
                      ),
                      Text(
                        '$selectedRating of 5',
                        style: theme
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                          color:
                              raGold,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed:
                            selectedRating ==
                                    0
                                ? null
                                : () =>
                                    Navigator.pop(
                                      sheetContext,
                                      selectedRating,
                                    ),
                        icon:
                            const Icon(
                          Icons
                              .check_rounded,
                        ),
                        label:
                            const Text(
                          'Submit Rating',
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

    if (rating == null ||
        !context.mounted) {
      return;
    }

    try {
      await RequestService()
          .submitDriverRating(
        requestId,
        rating,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for your $rating-star rating.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save rating. Try again.',
          ),
        ),
      );
    }
  }

  Widget _buildStatusHero(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final completed =
        status == 'completed';

    final cancelled =
        status == 'cancelled';

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
          colors: cancelled
              ? [
                  colors.error,
                  const Color(
                    0xFF9C2922,
                  ),
                ]
              : completed
                  ? [
                      raSuccess,
                      const Color(
                        0xFF087064,
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
            BorderRadius.circular(
          24,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: .14,
              ),
              borderRadius:
                  BorderRadius.circular(
                19,
              ),
            ),
            child: Icon(
              completed
                  ? Icons
                      .task_alt_rounded
                  : cancelled
                      ? Icons
                          .close_rounded
                      : Icons
                          .car_repair_outlined,
              color: Colors.white,
              size: 30,
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
                  statusLabel(),
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
                  height: 4,
                ),
                Text(
                  completed
                      ? 'Your roadside assistance has been completed.'
                      : cancelled
                          ? 'This roadside assistance request was cancelled.'
                          : 'View the latest information for this roadside assistance request.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: Colors
                        .white
                        .withValues(
                      alpha: .82,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
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
      child: Row(
        children: [
          ProfileInitials(
            name: provider,
            radius: 27,
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
                  provider,
                  maxLines: 1,
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
                  height: 3,
                ),
                Text(
                  providerAssigned
                      ? 'Assigned service provider'
                      : 'Provider not assigned',
                  style: theme
                      .textTheme.bodySmall,
                ),
              ],
            ),
          ),

          if (providerAssigned) ...[
            IconButton.filledTonal(
              tooltip: 'Call',
              onPressed:
                  providerPhone.isEmpty
                      ? null
                      : () =>
                          showCallPrompt(
                            context,
                            name:
                                provider,
                            number:
                                providerPhone,
                          ),
              icon: const Icon(
                Icons
                    .call_outlined,
              ),
            ),

            const SizedBox(
              width: RaSpace.xs,
            ),

            IconButton.filledTonal(
              tooltip: 'Message',
              onPressed: () =>
                  push(
                    context,
                    ChatScreen(
                      requestId:
                          requestId,
                      peerName:
                          provider,
                      peerPhone:
                          providerPhone,
                    ),
                  ),
              icon: const Icon(
                Icons
                    .chat_bubble_outline_rounded,
              ),
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

    final latitude =
        (data['latitude'] as num?)
                ?.toDouble() ??
            6.9034;

    final longitude =
        (data['longitude'] as num?)
                ?.toDouble() ??
            79.8525;

    final serviceFee =
        money('serviceFee');

    final travelFee =
        money('dispatchFee');

    final extraFee =
        money('extraFee');

    final quotedTotal =
        money('estimatedCost');

    final finalTotal =
        data['finalCost'] == null
            ? quotedTotal
            : money('finalCost');

    final location =
        data['locationLabel']
                as String? ??
            data['location']
                as String? ??
            'Pinned breakdown location';

    final vehicle =
        data['modelYear']
                as String? ??
            data['vehicleType']
                as String? ??
            'Not provided';

    final registration =
        data['registration']
                as String? ??
            'Not provided';

    final issue =
        data['issue'] as String? ??
            'Roadside assistance';

    final description =
        data['description']
                as String? ??
            '';

    final quoteNotes =
        data['quoteNotes']
                as String? ??
            '';

    final providerDistance =
        (data['providerDistanceKm']
                as num?)
            ?.toDouble();

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Request Details',
        ),
      ),

      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          _buildStatusHero(
            context,
          ),

          const SizedBox(
            height: RaSpace.lg,
          ),

          Container(
            height: 220,
            clipBehavior:
                Clip.antiAlias,
            decoration: BoxDecoration(
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
            child: MapMock(
              position: LatLng(
                latitude,
                longitude,
              ),
            ),
          ),

          const SizedBox(
            height: RaSpace.lg,
          ),

          if (providerAssigned) ...[
            _buildProviderCard(
              context,
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),
          ],

          Text(
            'Request information',
            style: theme
                .textTheme.titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          _RaRequestDetailsCard(
            children: [
              _RaRequestDetailRow(
                icon:
                    Icons.tag_rounded,
                label:
                    'Request ID',
                value:
                    requestId,
              ),
              _RaRequestDetailRow(
                icon:
                    Icons
                        .car_repair_outlined,
                label:
                    'Assistance',
                value:
                    issue,
              ),
              _RaRequestDetailRow(
                icon:
                    Icons
                        .directions_car_outlined,
                label:
                    'Vehicle',
                value:
                    vehicle,
              ),
              _RaRequestDetailRow(
                icon:
                    Icons.pin_outlined,
                label:
                    'Registration',
                value:
                    registration,
              ),
              _RaRequestDetailRow(
                icon:
                    Icons
                        .location_on_outlined,
                label:
                    'Location',
                value:
                    location,
              ),
              if (description
                  .trim()
                  .isNotEmpty)
                _RaRequestDetailRow(
                  icon:
                      Icons
                          .description_outlined,
                  label:
                      'Description',
                  value:
                      description,
                ),
            ],
          ),

          if (providerAssigned) ...[
            const SizedBox(
              height: RaSpace.xxl,
            ),

            Text(
              'Price summary',
              style: theme
                  .textTheme.titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            _RaRequestDetailsCard(
              children: [
                _RaRequestDetailRow(
                  icon:
                      Icons
                          .build_outlined,
                  label:
                      'Service / labour',
                  value:
                      formatMoney(
                    serviceFee,
                  ),
                ),
                _RaRequestDetailRow(
                  icon:
                      Icons
                          .route_outlined,
                  label:
                      'Travel / distance',
                  value:
                      formatMoney(
                    travelFee,
                  ),
                ),
                _RaRequestDetailRow(
                  icon:
                      Icons
                          .add_card_outlined,
                  label:
                      'Other charges',
                  value:
                      formatMoney(
                    extraFee,
                  ),
                ),
                if (providerDistance !=
                    null)
                  _RaRequestDetailRow(
                    icon:
                        Icons
                            .near_me_outlined,
                    label:
                        'Provider distance',
                    value:
                        '${providerDistance.toStringAsFixed(1)} km',
                  ),
                if (quoteNotes
                    .trim()
                    .isNotEmpty)
                  _RaRequestDetailRow(
                    icon:
                        Icons
                            .notes_outlined,
                    label:
                        'Quote notes',
                    value:
                        quoteNotes,
                  ),
                _RaRequestDetailRow(
                  icon:
                      Icons
                          .payments_outlined,
                  label:
                      data['finalCost'] ==
                              null
                          ? 'Quoted total'
                          : 'Final total',
                  value:
                      formatMoney(
                    finalTotal,
                  ),
                  strong: true,
                ),
              ],
            ),
          ],

          if (const [
            'accepted',
            'en_route',
            'arrived',
            'completed',
          ].contains(status)) ...[
            const SizedBox(
              height: RaSpace.xxl,
            ),

            Text(
              'Request progress',
              style: theme
                  .textTheme.titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
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
                    BorderRadius
                        .circular(20),
                border: Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .6,
                  ),
                ),
              ),
              child: StatusTimeline(
                statuses: const [
                  'Accepted',
                  'En Route',
                  'Arrived',
                  'Completed',
                ],
                current:
                    timelineIndex(),
              ),
            ),
          ],

          if (status ==
              'completed') ...[
            const SizedBox(
              height: RaSpace.xxl,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed: () =>
                        showReceipt(
                      context,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .receipt_long_outlined,
                    ),
                    label:
                        const Text(
                      'Receipt',
                    ),
                  ),
                ),

                const SizedBox(
                  width: RaSpace.sm,
                ),

                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed: () =>
                        rateService(
                      context,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .star_outline_rounded,
                    ),
                    label: Text(
                      data['driverRating'] ==
                              null
                          ? 'Rate'
                          : 'Update Rating',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  TextButton.icon(
                style:
                    TextButton.styleFrom(
                  foregroundColor:
                      colors.error,
                ),
                onPressed: () =>
                    push(
                  context,
                  DisputeScreen(
                    requestId:
                        requestId,
                  ),
                ),
                icon: const Icon(
                  Icons
                      .report_problem_outlined,
                ),
                label: const Text(
                  'Report a Problem',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RaRequestDetailsCard
    extends StatelessWidget {
  const _RaRequestDetailsCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: RaSpace.lg,
      ),
      decoration: BoxDecoration(
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
        children: [
          for (var index = 0;
              index < children.length;
              index++) ...[
            children[index],
            if (index !=
                children.length - 1)
              Divider(
                height: 1,
                indent: 50,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RaRequestDetailRow
    extends StatelessWidget {
  const _RaRequestDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: RaSpace.md,
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
                  .surfaceContainerHighest,
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
                    fontWeight: strong
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: strong
                        ? colors.primary
                        : null,
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