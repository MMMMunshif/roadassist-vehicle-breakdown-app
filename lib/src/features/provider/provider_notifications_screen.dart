part of '../../screens.dart';

class ProviderNotificationsScreen
    extends StatelessWidget {
  const ProviderNotificationsScreen({
    super.key,
  });

  Future<void> _sendQuote(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        request,
  ) async {
    final data =
        request.data();

    try {
      final quote =
          await requestProviderQuote(
        context,
        data,
      );

      if (quote == null ||
          !context.mounted) {
        return;
      }

      await RequestService()
          .acceptRequest(
        request.id,
        serviceFee:
            quote['serviceFee']
                as int,
        travelFee:
            quote['travelFee']
                as int,
        extraFee:
            quote['extraFee']
                as int,
        providerDistanceKm:
            quote[
                    'providerDistanceKm']
                as double,
        quoteNotes:
            quote['quoteNotes']
                as String,
        warrantyDays:
            quote['warrantyDays']
                as int,
        warrantyTerms:
            quote['warrantyTerms']
                as String,
        quoteType:
            quote['quoteType']
                as String,
      );

      if (!context.mounted) {
        return;
      }

      if (data['workflowVersion'] ==
          2) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Offer sent. Waiting for driver selection.',
            ),
          ),
        );

        return;
      }

      final acceptedData =
          Map<String, dynamic>.from(
        data,
      )
            ..addAll(quote)
            ..['dispatchFee'] =
                quote['travelFee']
            ..['estimatedCost'] =
                (quote['serviceFee']
                        as int) +
                    (quote['travelFee']
                        as int) +
                    (quote['extraFee']
                        as int)
            ..['status'] =
                'accepted';

      replace(
        context,
        ProviderActiveJobScreen(
          requestId:
              request.id,
          requestData:
              acceptedData,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      final activeJob =
          error
              .toString()
              .contains(
                'Complete your active job',
              );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            activeJob
                ? 'Complete your active job before accepting another request.'
                : 'This request is no longer available.',
          ),
        ),
      );
    }
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
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        title: const Text(
          'New Requests',
        ),
      ),

      body: Column(
        children: [
          Container(
            margin:
                const EdgeInsets
                    .fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              0,
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
            clipBehavior:
                Clip.antiAlias,
            child:
                const _ChatInbox(
              isProvider: true,
              preview: true,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          Expanded(
            child: StreamBuilder<
                DocumentSnapshot<
                    Map<String,
                        dynamic>>>(
              stream: signedIn
                  ? AuthService()
                      .watchCurrentProfile()
                  : null,
              builder: (
                context,
                profileSnapshot,
              ) {
                final savedServices =
                    profileSnapshot
                            .data
                            ?.data()?[
                        'services']
                        as List<
                            dynamic>?;

                final services =
                    savedServices ==
                                null ||
                            savedServices
                                .isEmpty
                        ? const [
                            'Vehicle Towing',
                            'Battery Jumpstart',
                            'Flat Tyre',
                            'General Mechanic',
                          ]
                        : savedServices
                            .whereType<
                                String>()
                            .toList();

                return StreamBuilder<
                    QuerySnapshot<
                        Map<String,
                            dynamic>>>(
                  stream: signedIn
                      ? RequestService()
                          .watchOpenRequests()
                      : null,
                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (!signedIn) {
                      return const EmptyState(
                        icon: Icons
                            .login_outlined,
                        title:
                            'Sign in required',
                        message:
                            'Sign in as a provider to view new requests.',
                      );
                    }

                    if (snapshot
                        .hasError) {
                      return const EmptyState(
                        icon: Icons
                            .cloud_off_outlined,
                        title:
                            'Unable to load requests',
                        message:
                            'Check your connection and try again.',
                      );
                    }

                    if (!snapshot
                        .hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final userId =
                        FirebaseAuth
                            .instance
                            .currentUser!
                            .uid;

                    final requests =
                        snapshot.data!.docs
                            .where(
                      (request) {
                        return _requestMatchesProvider(
                          request.data(),
                          userId,
                          services:
                              services,
                        );
                      },
                    ).toList();

                    requests.sort(
                      (a, b) {
                        final ap =
                            isHighPriority(
                          a.data()[
                                      'priority']
                                  as String? ??
                              'normal',
                        );

                        final bp =
                            isHighPriority(
                          b.data()[
                                      'priority']
                                  as String? ??
                              'normal',
                        );

                        if (ap != bp) {
                          return ap
                              ? -1
                              : 1;
                        }

                        final at =
                            (a.data()[
                                        'createdAt']
                                    as Timestamp?)
                                ?.toDate();

                        final bt =
                            (b.data()[
                                        'createdAt']
                                    as Timestamp?)
                                ?.toDate();

                        if (at == null ||
                            bt == null) {
                          return 0;
                        }

                        return bt
                            .compareTo(at);
                      },
                    );

                    if (requests
                        .isEmpty) {
                      return const EmptyState(
                        icon: Icons
                            .inbox_outlined,
                        title:
                            'No new requests',
                        message:
                            'Matching driver requests will appear here in real time.',
                      );
                    }

                    return ListView(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        RaSpace.lg,
                        0,
                        RaSpace.lg,
                        RaSpace.xxl,
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    'Available nearby',
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
                                    height: 3,
                                  ),
                                  Text(
                                    'Requests matching your enabled services.',
                                    style: theme
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    9,
                                vertical: 5,
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
                              child: Text(
                                '${requests.length}',
                                style: theme
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                  color: colors
                                      .onPrimaryContainer,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height:
                              RaSpace.md,
                        ),

                        for (var index =
                                0;
                            index <
                                requests
                                    .length;
                            index++) ...[
                          _ProviderRequestInboxCard(
                            request:
                                requests[
                                    index],
                            onDismiss:
                                () async {
                              await RequestService()
                                  .rejectRequest(
                                requests[
                                        index]
                                    .id,
                              );
                            },
                            onQuote:
                                () =>
                                    _sendQuote(
                              context,
                              requests[
                                  index],
                            ),
                          ),
                          if (index !=
                              requests
                                      .length -
                                  1)
                            const SizedBox(
                              height:
                                  RaSpace.sm,
                            ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRequestInboxCard
    extends StatelessWidget {
  const _ProviderRequestInboxCard({
    required this.request,
    required this.onDismiss,
    required this.onQuote,
  });

  final QueryDocumentSnapshot<
          Map<String, dynamic>>
      request;

  final VoidCallback onDismiss;
  final VoidCallback onQuote;

  String _createdLabel(
    Map<String, dynamic> data,
  ) {
    final created =
        (data['createdAt']
                as Timestamp?)
            ?.toDate()
            .toLocal();

    if (created == null) {
      return 'New request';
    }

    final difference =
        DateTime.now()
            .difference(created);

    if (difference.inMinutes <
        1) {
      return 'Just now';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes} min ago';
    }

    return '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final data =
        request.data();

    final driver =
        data['driverName']
                as String? ??
            'Driver';

    final priority =
        data['priority']
                as String? ??
            'normal';

    final urgent =
        isHighPriority(priority);

    final latitude =
        (data['latitude'] as num?)
            ?.toDouble();

    final longitude =
        (data['longitude'] as num?)
            ?.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: urgent
              ? colors.error
                  .withValues(
                  alpha: .48,
                )
              : colors
                  .outlineVariant
                  .withValues(
                  alpha: .6,
                ),
          width: urgent
              ? 1.5
              : 1,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          if (urgent)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    RaSpace.md,
                vertical:
                    RaSpace.sm,
              ),
              color: colors
                  .errorContainer
                  .withValues(
                alpha: .52,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .warning_amber_rounded,
                    size: 18,
                    color:
                        colors.error,
                  ),
                  const SizedBox(
                    width:
                        RaSpace.sm,
                  ),
                  Expanded(
                    child: Text(
                      requestPriorityLabel(
                        priority,
                      ).toUpperCase(),
                      style: theme
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                        color:
                            colors.error,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (latitude != null &&
              longitude != null)
            SizedBox(
              height: 130,
              child: MapMock(
                position: LatLng(
                  latitude,
                  longitude,
                ),
              ),
            ),

          Padding(
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
                    ProfileInitials(
                      name: driver,
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
                            driver,
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
                          Text(
                            _createdLabel(
                              data,
                            ),
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const StatusPill(
                      label: 'NEW',
                      tone:
                          RaTone.warning,
                      dot: false,
                    ),
                  ],
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                _ProviderRequestLine(
                  icon: Icons
                      .car_repair_outlined,
                  text:
                      requestIssueLabel(
                    data,
                  ),
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                _ProviderRequestLine(
                  icon: Icons
                      .location_on_outlined,
                  text:
                      data['locationLabel']
                              as String? ??
                          'Pinned location',
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                _ProviderRequestLine(
                  icon: Icons
                      .directions_car_outlined,
                  text:
                      data['modelYear']
                              as String? ??
                          data['vehicleType']
                              as String? ??
                          'Vehicle details unavailable',
                ),

                const SizedBox(
                  height: RaSpace.md,
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
                        .primaryContainer
                        .withValues(
                      alpha: .30,
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
                            .request_quote_outlined,
                        color:
                            colors.primary,
                        size: 18,
                      ),
                      const SizedBox(
                        width:
                            RaSpace.sm,
                      ),
                      Expanded(
                        child: Text(
                          data['workflowVersion'] ==
                                  2
                              ? 'Your itemized quote is required'
                              : 'Current estimate: Rs. ${data['estimatedCost'] ?? 0}',
                          style: theme
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color: colors
                                .primary,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton(
                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              colors.error,
                        ),
                        onPressed:
                            onDismiss,
                        child: const Text(
                          'Dismiss',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    Expanded(
                      flex: 2,
                      child:
                          FilledButton.icon(
                        onPressed:
                            onQuote,
                        icon: const Icon(
                          Icons
                              .request_quote_outlined,
                        ),
                        label: const Text(
                          'Review & Quote',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRequestLine
    extends StatelessWidget {
  const _ProviderRequestLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

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
          child: Text(
            text,
            style:
                Theme.of(context)
                    .textTheme
                    .bodyMedium,
          ),
        ),
      ],
    );
  }
}