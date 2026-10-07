part of '../../screens.dart';

class ProviderRequestDetailsScreen
    extends StatelessWidget {
  const ProviderRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  String _money(
    dynamic value,
  ) {
    return 'Rs. ${(value as num?)?.toInt() ?? 0}';
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
            ?.toDouble();

    final longitude =
        (data['longitude'] as num?)
            ?.toDouble();

    final driver =
        data['driverName']
                as String? ??
            'Driver';

    final phone =
        data['driverPhone']
                as String? ??
            '';

    final rawStatus =
        data['status']
                as String? ??
            'unknown';

    final status =
        rawStatus
            .replaceAll('_', ' ')
            .toUpperCase();

    final created =
        (data['createdAt']
                as Timestamp?)
            ?.toDate()
            .toLocal();

    final createdLabel =
        created == null
            ? 'Time unavailable'
            : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} • ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    final registration =
        data['registration']
                as String? ??
            'Not provided';

    final vehiclePhotos =
        (data['vehiclePhotoUrls']
                    as List<dynamic>? ??
                const [])
            .whereType<String>()
            .toList();

    final tone =
        rawStatus == 'completed'
            ? RaTone.success
            : rawStatus ==
                    'cancelled'
                ? RaTone.danger
                : RaTone.info;

    return Scaffold(
      backgroundColor:
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Job Details',
        ),
        actions: [
          if (rawStatus ==
              'completed')
            IconButton(
              tooltip: 'Invoice',
              onPressed: () =>
                  push(
                context,
                InvoiceScreen(
                  requestId:
                      requestId,
                ),
              ),
              icon: const Icon(
                Icons
                    .receipt_long_outlined,
              ),
            ),
          const SizedBox(
            width: RaSpace.sm,
          ),
        ],
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
          Container(
            padding:
                const EdgeInsets.all(
              RaSpace.xl,
            ),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors:
                    rawStatus ==
                            'cancelled'
                        ? [
                            colors
                                .error,
                            const Color(
                              0xFF9B2922,
                            ),
                          ]
                        : rawStatus ==
                                'completed'
                            ? [
                                raSuccess,
                                const Color(
                                  0xFF087064,
                                ),
                              ]
                            : [
                                colors
                                    .primary,
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
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: status,
                      tone: tone,
                      dot: false,
                    ),
                    const Spacer(),
                    Text(
                      createdLabel,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: .74,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: RaSpace.lg,
                ),

                Text(
                  requestIssueLabel(
                    data,
                  ),
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
                  height: 5,
                ),

                Text(
                  'Job $requestId',
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: Colors.white
                        .withValues(
                      alpha: .78,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Customer',
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
                Row(
                  children: [
                    ProfileInitials(
                      name: driver,
                      radius: 26,
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
                            driver,
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
                            phone.isEmpty
                                ? 'Phone not provided'
                                : phone,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),

                    IconButton.filledTonal(
                      tooltip:
                          'Call customer',
                      onPressed:
                          phone.isEmpty
                              ? null
                              : () =>
                                  showCallPrompt(
                                    context,
                                    name:
                                        driver,
                                    number:
                                        phone,
                                  ),
                      icon: const Icon(
                        Icons
                            .call_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      RaSpace.md,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () =>
                        push(
                      context,
                      CustomerContactScreen(
                        requestId:
                            requestId,
                        requestData:
                            data,
                      ),
                    ),
                    icon: const Icon(
                      Icons
                          .chat_bubble_outline_rounded,
                    ),
                    label: const Text(
                      'Contact Customer',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Vehicle',
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
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  child:
                      VehiclePhotoPreview(
                    model:
                        data['modelYear']
                                as String? ??
                            '',
                    photoData:
                        requestVehiclePhoto(
                      data,
                    ),
                    height: 155,
                  ),
                ),

                const SizedBox(
                  height:
                      RaSpace.md,
                ),

                _ProviderDetailRow(
                  icon: Icons
                      .directions_car_outlined,
                  label: 'Type',
                  value:
                      data['vehicleType']
                              as String? ??
                          'Not provided',
                ),

                _ProviderDetailRow(
                  icon: Icons
                      .badge_outlined,
                  label: 'Model',
                  value:
                      data['modelYear']
                              as String? ??
                          'Not provided',
                ),

                _ProviderDetailRow(
                  icon:
                      Icons.pin_outlined,
                  label:
                      'Registration',
                  value:
                      registration,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Incident',
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
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                _ProviderDetailRow(
                  icon: Icons
                      .car_repair_outlined,
                  label:
                      'Breakdown',
                  value:
                      requestIssueLabel(
                    data,
                  ),
                ),

                _ProviderDetailRow(
                  icon: Icons
                      .location_on_outlined,
                  label:
                      'Location',
                  value:
                      data['locationLabel']
                              as String? ??
                          'Pinned location',
                ),

                if ((data['description']
                            as String? ??
                        '')
                    .trim()
                    .isNotEmpty)
                  _ProviderDetailRow(
                    icon: Icons
                        .description_outlined,
                    label:
                        'Customer description',
                    value:
                        data['description']
                            as String,
                  ),

                if ((data['notes']
                            as String? ??
                        '')
                    .trim()
                    .isNotEmpty)
                  _ProviderDetailRow(
                    icon: Icons
                        .notes_outlined,
                    label:
                        'Additional notes',
                    value:
                        data['notes']
                            as String,
                  ),

                if (latitude != null &&
                    longitude != null) ...[
                  const SizedBox(
                    height:
                        RaSpace.md,
                  ),
                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                    child: SizedBox(
                      height: 190,
                      child: MapMock(
                        position:
                            LatLng(
                          latitude,
                          longitude,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),

                  OutlinedButton.icon(
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
                      'Open GPS Navigation',
                    ),
                  ),
                ],

                if (vehiclePhotos
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        RaSpace.lg,
                  ),
                  Text(
                    'Driver evidence',
                    style: theme
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height:
                        RaSpace.sm,
                  ),
                  SizedBox(
                    height: 100,
                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount:
                          vehiclePhotos
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
                        try {
                          return ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            child:
                                Image.memory(
                              base64Decode(
                                vehiclePhotos[
                                    index],
                              ),
                              width: 125,
                              height: 100,
                              fit: BoxFit
                                  .cover,
                            ),
                          );
                        } on FormatException {
                          return Container(
                            width: 125,
                            alignment:
                                Alignment
                                    .center,
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons
                                  .broken_image_outlined,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Quote & payment',
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
                const EdgeInsets
                    .symmetric(
              horizontal:
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
            child: Column(
              children: [
                _ProviderDetailRow(
                  icon:
                      Icons.build_outlined,
                  label:
                      'Service / labour',
                  value:
                      _money(
                    data['serviceFee'],
                  ),
                ),
                _ProviderDetailRow(
                  icon:
                      Icons.route_outlined,
                  label:
                      'Travel / distance',
                  value:
                      _money(
                    data['dispatchFee'],
                  ),
                ),
                _ProviderDetailRow(
                  icon: Icons
                      .add_card_outlined,
                  label:
                      'Other charges',
                  value:
                      _money(
                    data['extraFee'],
                  ),
                ),
                if ((data[
                            'providerDistanceKm']
                        as num?) !=
                    null)
                  _ProviderDetailRow(
                    icon: Icons
                        .near_me_outlined,
                    label:
                        'Provider distance',
                    value:
                        '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
                  ),
                if ((data['quoteNotes']
                            as String? ??
                        '')
                    .isNotEmpty)
                  _ProviderDetailRow(
                    icon:
                        Icons.notes_outlined,
                    label:
                        'Quote notes',
                    value:
                        data['quoteNotes']
                            as String,
                  ),
                _ProviderDetailRow(
                  icon: Icons
                      .payments_outlined,
                  label:
                      data['finalCost'] ==
                              null
                          ? 'Quoted total'
                          : 'Final total',
                  value:
                      _money(
                    data['finalCost'] ??
                        data[
                            'estimatedCost'],
                  ),
                  strong: true,
                ),
                if (data[
                        'driverRating'] !=
                    null)
                  _ProviderDetailRow(
                    icon:
                        Icons.star_rounded,
                    label:
                        'Driver rating',
                    value:
                        '${data['driverRating']} / 5',
                  ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Assigned provider',
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

          StreamBuilder<
              DocumentSnapshot<
                  Map<String,
                      dynamic>>>(
            stream: signedIn
                ? AuthService()
                    .watchCurrentProfile()
                : null,
            builder: (
              context,
              snapshot,
            ) {
              final profile =
                  snapshot.data
                      ?.data();

              final providerName =
                  profile?[
                              'displayName']
                          as String? ??
                      'Service Provider';

              final services =
                  (profile?[
                                  'services']
                              as List<
                                  dynamic>? ??
                          const [])
                      .whereType<
                          String>()
                      .join(', ');

              return Container(
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
                child: Row(
                  children: [
                    ProfileInitials(
                      name:
                          providerName,
                      radius: 23,
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
                            providerName,
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
                            services.isEmpty
                                ? 'RoadAssist Provider'
                                : services,
                            maxLines: 2,
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
                    const StatusPill(
                      label:
                          'Assigned',
                      tone:
                          RaTone.info,
                      dot: false,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Vehicle history',
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

          StreamBuilder<
              QuerySnapshot<
                  Map<String,
                      dynamic>>>(
            stream: signedIn
                ? RequestService()
                    .watchProviderRequests()
                : null,
            builder: (
              context,
              snapshot,
            ) {
              final previous =
                  snapshot.data?.docs
                          .where(
                    (request) {
                      final history =
                          request.data();

                      return request.id !=
                              requestId &&
                          registration !=
                              'Not provided' &&
                          history[
                                  'registration'] ==
                              registration &&
                          history[
                                  'status'] ==
                              'completed';
                    },
                  ).take(3).toList() ??
                      const [];

              if (previous.isEmpty) {
                return Container(
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
                      18,
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
                  child:
                      const InlineMessage(
                    icon: Icons
                        .history_outlined,
                    text:
                        'No previous completed services for this vehicle with your account.',
                  ),
                );
              }

              return Container(
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
                clipBehavior:
                    Clip.antiAlias,
                child: Column(
                  children:
                      previous.map(
                    (request) {
                      final history =
                          request.data();

                      final completed =
                          (history[
                                      'completedAt']
                                  as Timestamp?)
                              ?.toDate();

                      final date = completed ==
                              null
                          ? 'Completed service'
                          : '${completed.day.toString().padLeft(2, '0')}/${completed.month.toString().padLeft(2, '0')}/${completed.year}';

                      return ListTile(
                        leading:
                            const IconBadge(
                          Icons
                              .build_circle_outlined,
                          size: 38,
                        ),
                        title: Text(
                          history['issue']
                                  as String? ??
                              'Roadside assistance',
                          style: theme
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        subtitle:
                            Text(date),
                        trailing:
                            const Icon(
                          Icons
                              .chevron_right_rounded,
                        ),
                        onTap: () =>
                            push(
                          context,
                          ProviderRequestDetailsScreen(
                            requestId:
                                request.id,
                            data:
                                history,
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderDetailRow
    extends StatelessWidget {
  const _ProviderDetailRow({
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
  Widget build(
    BuildContext context,
  ) {
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
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: strong
                  ? colors.primary
                  : colors
                      .onSurfaceVariant,
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
                    color: strong
                        ? colors.primary
                        : null,
                    fontWeight: strong
                        ? FontWeight.w900
                        : FontWeight.w700,
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