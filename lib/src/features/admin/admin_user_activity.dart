part of '../../screens.dart';

class _AdminUserActivity
    extends StatelessWidget {
  const _AdminUserActivity({
    required this.uid,
  });

  final String uid;

  DateTime? _requestDate(
    Map<String, dynamic> data,
  ) {
    final value =
        data['updatedAt'] ??
            data['completedAt'] ??
            data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  List<QueryDocumentSnapshot<
          Map<String, dynamic>>>
      _sortedRequests(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final result =
        documents.toList();

    result.sort(
      (
        first,
        second,
      ) {
        final firstDate =
            _requestDate(
          first.data(),
        );

        final secondDate =
            _requestDate(
          second.data(),
        );

        if (firstDate == null &&
            secondDate == null) {
          return 0;
        }

        if (firstDate == null) {
          return 1;
        }

        if (secondDate == null) {
          return -1;
        }

        return secondDate.compareTo(
          firstDate,
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.all(
            17,
          ),
          decoration: BoxDecoration(
            color: colors.primary
                .withValues(
              alpha: .065,
            ),
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border: Border.all(
              color: colors.primary
                  .withValues(
                alpha: .13,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primary
                      .withValues(
                    alpha: .09,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons
                      .manage_history_outlined,
                  color:
                      colors.primary,
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
                      'Account activity',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -.25,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Review recent RoadAssist jobs, cancellations and administrative actions associated with this account.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.7,
                        height: 1.45,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        for (final field in [
          'driverId',
          'providerId',
        ])
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 9,
            ),
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream: FirebaseFirestore
                  .instance
                  .collection(
                    'requests',
                  )
                  .where(
                    field,
                    isEqualTo:
                        uid,
                  )
                  .limit(
                    50,
                  )
                  .snapshots(),
              builder: (
                context,
                snapshot,
              ) {
                final driver =
                    field ==
                        'driverId';

                final label =
                    driver
                        ? 'Driver jobs'
                        : 'Provider jobs';

                if (snapshot
                    .hasError) {
                  return _RaAdminActivitySection(
                    icon: driver
                        ? Icons
                            .directions_car_outlined
                        : Icons
                            .home_repair_service_outlined,
                    title:
                        label,
                    subtitle:
                        'Could not load related jobs.',
                    children:
                        const [],
                  );
                }

                if (!snapshot
                    .hasData) {
                  return _RaAdminActivitySection(
                    icon: driver
                        ? Icons
                            .directions_car_outlined
                        : Icons
                            .home_repair_service_outlined,
                    title:
                        label,
                    subtitle:
                        'Loading job history…',
                    loading:
                        true,
                    children:
                        const [],
                  );
                }

                final docs =
                    _sortedRequests(
                  snapshot
                      .data!
                      .docs,
                );

                return _RaAdminActivitySection(
                  icon: driver
                      ? Icons
                          .directions_car_outlined
                      : Icons
                          .home_repair_service_outlined,
                  title:
                      '$label (${docs.length})',
                  subtitle:
                      'Up to 50 recent records',
                  children: [
                    if (docs
                        .isEmpty)
                      const _RaAdminActivityEmpty(
                        text:
                            'No related jobs found.',
                      ),

                    for (final doc
                        in docs)
                      _RaAdminActivityJobTile(
                        requestId:
                            doc.id,
                        data:
                            doc.data(),
                      ),
                  ],
                );
              },
            ),
          ),

        Padding(
          padding:
              const EdgeInsets.only(
            bottom: 9,
          ),
          child: StreamBuilder<
              QuerySnapshot<
                  Map<String,
                      dynamic>>>(
            stream: FirebaseFirestore
                .instance
                .collection(
                  'requests',
                )
                .where(
                  'cancelledBy',
                  isEqualTo:
                      uid,
                )
                .limit(
                  50,
                )
                .snapshots(),
            builder: (
              context,
              snapshot,
            ) {
              final rawDocs =
                  snapshot
                          .data
                          ?.docs ??
                      <QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>[];

              final docs =
                  _sortedRequests(
                rawDocs,
              );

              return _RaAdminActivitySection(
                icon: Icons
                    .cancel_outlined,
                title:
                    'Cancellations (${docs.length})',
                subtitle:
                    'Requests cancelled by this account',
                loading:
                    !snapshot.hasData &&
                        !snapshot
                            .hasError,
                children: [
                  if (snapshot
                      .hasError)
                    const _RaAdminActivityEmpty(
                      text:
                          'Could not load cancellation history.',
                    ),

                  if (snapshot
                          .hasData &&
                      docs.isEmpty)
                    const _RaAdminActivityEmpty(
                      text:
                          'No cancellations recorded.',
                    ),

                  for (final doc
                      in docs)
                    _RaAdminCancellationTile(
                      requestId:
                          doc.id,
                      data:
                          doc.data(),
                    ),
                ],
              );
            },
          ),
        ),

        StreamBuilder<
            QuerySnapshot<
                Map<String,
                    dynamic>>>(
          stream: FirebaseFirestore
              .instance
              .collection(
                'adminAudit',
              )
              .where(
                'target',
                isEqualTo:
                    uid,
              )
              .limit(
                50,
              )
              .snapshots(),
          builder: (
            context,
            snapshot,
          ) {
            final docs =
                snapshot
                        .data
                        ?.docs
                        .toList() ??
                    <QueryDocumentSnapshot<
                        Map<String,
                            dynamic>>>[];

            docs.sort(
              (
                first,
                second,
              ) {
                final firstTime =
                    first.data()[
                        'createdAt'];

                final secondTime =
                    second.data()[
                        'createdAt'];

                if (firstTime
                        is Timestamp &&
                    secondTime
                        is Timestamp) {
                  return secondTime
                      .compareTo(
                    firstTime,
                  );
                }

                return 0;
              },
            );

            return _RaAdminActivitySection(
              icon:
                  Icons.history_rounded,
              title:
                  'Audit history (${docs.length})',
              subtitle:
                  'Administrative actions targeting this account',
              loading:
                  !snapshot.hasData &&
                      !snapshot.hasError,
              children: [
                if (snapshot.hasError)
                  const _RaAdminActivityEmpty(
                    text:
                        'Could not load audit history.',
                  ),

                if (snapshot.hasData &&
                    docs.isEmpty)
                  const _RaAdminActivityEmpty(
                    text:
                        'No audit entries recorded.',
                  ),

                for (final doc
                    in docs)
                  _RaAdminAuditTile(
                    data:
                        doc.data(),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RaAdminActivitySection
    extends StatelessWidget {
  const _RaAdminActivitySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.loading = false,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final List<Widget>
      children;

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : colors.surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets
                .symmetric(
          horizontal: 13,
          vertical: 3,
        ),
        childrenPadding:
            const EdgeInsets
                .fromLTRB(
          8,
          0,
          8,
          8,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(
            color: colors.primary
                .withValues(
              alpha: .075,
            ),
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
                colors.primary,
          ),
        ),
        title: Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8,
            color: colors
                .onSurfaceVariant,
          ),
        ),
        children: [
          if (loading)
            const Padding(
              padding:
                  EdgeInsets.all(
                18,
              ),
              child:
                  LinearProgressIndicator(),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _RaAdminActivityJobTile
    extends StatelessWidget {
  const _RaAdminActivityJobTile({
    required this.requestId,
    required this.data,
  });

  final String requestId;

  final Map<String, dynamic>
      data;

  String _statusLabel(
    String status,
  ) {
    return switch (status) {
      'en_route' =>
        'En route',
      'completed' =>
        'Completed',
      'cancelled' =>
        'Cancelled',
      'searching' =>
        'Searching',
      'accepted' =>
        'Accepted',
      'arrived' =>
        'Arrived',
      _ =>
        status
            .replaceAll(
              '_',
              ' ',
            )
            .trim(),
    };
  }

  RaTone _statusTone(
    String status,
  ) {
    return switch (status) {
      'completed' =>
        RaTone.success,
      'cancelled' =>
        RaTone.danger,
      'searching' =>
        RaTone.warning,
      'accepted' ||
      'en_route' ||
      'arrived' =>
        RaTone.info,
      _ =>
        RaTone.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final status =
        data['status']
                ?.toString() ??
            'unknown';

    final paymentConfirmed =
        data['providerConfirmedPayment'] ==
            true;

    final arrivalConfirmed =
        data['arrivalConfirmedBy'] !=
            null;

    final location =
        data['locationLabel']
                ?.toString() ??
            data['location']
                ?.toString() ??
            '';

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        onTap: () {
          push(
            context,
            AdminJobMonitorScreen(
              requestId:
                  requestId,
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 9,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .45,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child: Icon(
                  Icons
                      .route_outlined,
                  size: 18,
                  color:
                      colors.primary,
                ),
              ),

              const SizedBox(
                width: 9,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            requestIssueLabel(
                              data,
                            ),
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize:
                                  9.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        StatusPill(
                          label:
                              _statusLabel(
                            status,
                          ),
                          tone:
                              _statusTone(
                            status,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Request $requestId',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 7.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    if (location
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        location,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize:
                              7.7,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 6,
                    ),

                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _RaAdminMiniBadge(
                          icon: paymentConfirmed
                              ? Icons
                                  .payments_outlined
                              : Icons
                                  .payment_outlined,
                          label: paymentConfirmed
                              ? 'Payment confirmed'
                              : 'Payment unconfirmed',
                          tone: paymentConfirmed
                              ? raSuccess
                              : raGold,
                        ),
                        if (arrivalConfirmed)
                          const _RaAdminMiniBadge(
                            icon: Icons
                                .location_on_outlined,
                            label:
                                'Arrival confirmed',
                            tone:
                                raSuccess,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaAdminCancellationTile
    extends StatelessWidget {
  const _RaAdminCancellationTile({
    required this.requestId,
    required this.data,
  });

  final String requestId;

  final Map<String, dynamic>
      data;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final type =
        data['cancellationType']
                ?.toString() ??
            'Cancellation';

    final reason =
        data['cancellationReason']
                ?.toString() ??
            'No reason recorded';

    return ListTile(
      contentPadding:
          const EdgeInsets
              .symmetric(
        horizontal: 9,
        vertical: 2,
      ),
      leading: Container(
        width: 38,
        height: 38,
        decoration:
            BoxDecoration(
          color: raDanger
              .withValues(
            alpha: .07,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: const Icon(
          Icons
              .cancel_schedule_send_outlined,
          color:
              raDanger,
          size: 18,
        ),
      ),
      title: Text(
        type,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '$reason\nRequest $requestId',
        maxLines: 3,
        overflow:
            TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 7.8,
          height: 1.4,
          color: colors
              .onSurfaceVariant,
        ),
      ),
      isThreeLine: true,
      trailing: const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap: () {
        push(
          context,
          AdminJobMonitorScreen(
            requestId:
                requestId,
          ),
        );
      },
    );
  }
}

class _RaAdminAuditTile
    extends StatelessWidget {
  const _RaAdminAuditTile({
    required this.data,
  });

  final Map<String, dynamic>
      data;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final kind =
        data['kind']
                ?.toString() ??
            'Admin action';

    final reason =
        data['reason']
                ?.toString() ??
            'No reason recorded';

    final actor =
        data['actor']
                ?.toString() ??
            'Unknown';

    return ListTile(
      contentPadding:
          const EdgeInsets
              .symmetric(
        horizontal: 9,
        vertical: 2,
      ),
      leading: Container(
        width: 38,
        height: 38,
        decoration:
            BoxDecoration(
          color: colors
              .primary
              .withValues(
            alpha: .07,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: Icon(
          Icons
              .admin_panel_settings_outlined,
          color:
              colors.primary,
          size: 18,
        ),
      ),
      title: Text(
        kind,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '$reason\nActor: $actor',
        maxLines: 3,
        overflow:
            TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 7.8,
          height: 1.4,
          color: colors
              .onSurfaceVariant,
        ),
      ),
      isThreeLine:
          true,
      trailing:
          const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap: () {
        push(
          context,
          _AdminAuditScreen(
            data:
                data,
          ),
        );
      },
    );
  }
}

class _RaAdminMiniBadge
    extends StatelessWidget {
  const _RaAdminMiniBadge({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tone
            .withValues(
          alpha: .07,
        ),
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
            icon,
            size: 12,
            color: tone,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 6.9,
              fontWeight:
                  FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminActivityEmpty
    extends StatelessWidget {
  const _RaAdminActivityEmpty({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.all(
        16,
      ),
      child: Text(
        text,
        textAlign:
            TextAlign.center,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 8.5,
          color: colors
              .onSurfaceVariant,
        ),
      ),
    );
  }
}