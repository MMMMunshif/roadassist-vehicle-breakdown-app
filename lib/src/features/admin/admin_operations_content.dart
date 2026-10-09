part of '../../screens.dart';

class _AdminOperationsPanel extends StatefulWidget {
  const _AdminOperationsPanel({
    super.key,
    required this.mode,
  });

  final String mode;

  @override
  State<_AdminOperationsPanel> createState() =>
      _AdminOperationsPanelState();
}

class _AdminOperationsPanelState extends State<_AdminOperationsPanel> {
  int limit = 100;

  bool attentionOnly = true;

  Timer? clock;

  late Stream<QuerySnapshot<Map<String, dynamic>>> jobs;

  @override
  void initState() {
    super.initState();

    _connect();

    clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    clock?.cancel();

    super.dispose();
  }

  void _connect() {
    jobs = FirebaseFirestore.instance
        .collection('requests')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(limit)
        .snapshots();
  }

  DateTime? _timestamp(
    Object? value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  DateTime? _lastActivity(
    Map<String, dynamic> data,
  ) {
    return _timestamp(
          data['updatedAt'],
        ) ??
        _timestamp(
          data['createdAt'],
        );
  }

  int _ageMinutes(
    Map<String, dynamic> data, {
    bool fromCreatedAt = false,
  }) {
    final date = fromCreatedAt
        ? _timestamp(
            data['createdAt'],
          )
        : _lastActivity(data);

    if (date == null) {
      return 0;
    }

    final difference =
        DateTime.now().difference(date);

    if (difference.isNegative) {
      return 0;
    }

    return difference.inMinutes;
  }

  int _amount(
    Map<String, dynamic> data,
  ) {
    return (data['finalCost'] as num?)?.toInt() ??
        (data['estimatedCost'] as num?)?.toInt() ??
        0;
  }

  String _money(
    num value,
  ) {
    final rounded =
        value.round();

    final negative =
        rounded < 0;

    final digits =
        rounded.abs().toString();

    final buffer =
        StringBuffer();

    for (var index = 0;
        index < digits.length;
        index++) {
      if (index > 0 &&
          (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(
        digits[index],
      );
    }

    return 'Rs. ${negative ? '-' : ''}${buffer.toString()}';
  }

  String _csvCell(
    Object? value,
  ) {
    var text =
        '${value ?? ''}';

    if (RegExp(
      r'^\s*[=+@\-\t\r]',
    ).hasMatch(text)) {
      text = "'$text";
    }

    return '"${text.replaceAll('"', '""')}"';
  }

  bool _matchesService(
    Map<String, dynamic> data,
    String service,
  ) {
    final issues =
        (data['issues'] as List<dynamic>? ?? const [])
            .whereType<String>();

    if (issues.contains(service)) {
      return true;
    }

    return data['issue'] == service;
  }

  String _statusLabel(
    String status,
  ) {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status
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
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'searching' => RaTone.warning,
      'accepted' ||
      'en_route' ||
      'arrived' =>
        RaTone.info,
      _ => RaTone.info,
    };
  }

  Future<void> _loadMore() async {
    setState(() {
      limit += 100;

      _connect();
    });
  }

  Future<void> _export(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        docs,
  ) async {
    final csv = [
      [
        'job',
        'status',
        'service',
        'approved_amount',
        'final_amount',
        'payment_confirmed',
        'created_at',
      ].map(_csvCell).join(','),
      for (final document in docs)
        [
          document.id,
          document.data()['status'],
          requestIssueLabel(
            document.data(),
          ),
          document.data()['estimatedCost'],
          document.data()['finalCost'],
          document.data()['providerConfirmedPayment'] ==
              true,
          _timestamp(
            document.data()['createdAt'],
          )?.toIso8601String(),
        ].map(_csvCell).join(','),
    ].join('\r\n');

    final result =
        await exportProviderReport(
      csv,
      'roadassist-admin-jobs.csv',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: jobs,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: _RaAdminOpsNotice(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load operations',
              message:
                  'Check the current admin permission and network connection.',
              tone: raDanger,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data!.docs;

        final completed =
            docs.where(
          (document) =>
              document.data()['status'] ==
              'completed',
        ).toList();

        final confirmed =
            completed.where(
          (document) =>
              document.data()['providerConfirmedPayment'] ==
              true,
        ).toList();

        final reported =
            completed.where(
          (document) {
            final data =
                document.data();

            return data['driverReportedPayment'] ==
                    true &&
                data['providerConfirmedPayment'] !=
                    true;
          },
        ).toList();

        final unpaid =
            completed.where(
          (document) {
            final data =
                document.data();

            return data['driverReportedPayment'] !=
                    true &&
                data['providerConfirmedPayment'] !=
                    true;
          },
        ).toList();

        final waiting =
            docs.where(
          (document) {
            final data =
                document.data();

            return data['status'] ==
                    'searching' &&
                _ageMinutes(
                      data,
                      fromCreatedAt: true,
                    ) >=
                    15;
          },
        ).toList();

        final stalled =
            docs.where(
          (document) {
            final data =
                document.data();

            final status =
                data['status'];

            return const [
                  'accepted',
                  'en_route',
                  'arrived',
                ].contains(status) &&
                _ageMinutes(data) >=
                    60;
          },
        ).toList();

        final attentionMap = <
            String,
            QueryDocumentSnapshot<
                Map<String, dynamic>>>{
          for (final document in waiting)
            document.id: document,
          for (final document in stalled)
            document.id: document,
        };

        final shown =
            switch (widget.mode) {
          'payments' =>
            completed.where(
              (document) {
                return !attentionOnly ||
                    document.data()[
                            'providerConfirmedPayment'] !=
                        true;
              },
            ).toList(),
          'operations' =>
            attentionMap.values.toList(),
          _ => docs,
        };

        final confirmedTotal =
            confirmed.fold<double>(
          0,
          (
            total,
            document,
          ) {
            return total +
                _amount(
                  document.data(),
                );
          },
        );

        final cancelled =
            docs.where(
          (document) =>
              document.data()['status'] ==
              'cancelled',
        ).length;

        return ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            32,
          ),
          children: [
            _RaAdminOpsLoadedDataNotice(
              count: docs.length,
              limit: limit,
            ),

            const SizedBox(
              height: 15,
            ),

            if (widget.mode ==
                'operations')
              _RaAdminOpsMetricGrid(
                metrics: [
                  (
                    'Waiting 15+ min',
                    '${waiting.length}',
                    Icons
                        .hourglass_top_rounded,
                    waiting.isEmpty
                        ? raSuccess
                        : raGold,
                  ),
                  (
                    'No update 60+ min',
                    '${stalled.length}',
                    Icons
                        .update_disabled_outlined,
                    stalled.isEmpty
                        ? raSuccess
                        : raDanger,
                  ),
                  (
                    'Attention jobs',
                    '${attentionMap.length}',
                    Icons
                        .warning_amber_rounded,
                    attentionMap.isEmpty
                        ? raSuccess
                        : raGold,
                  ),
                  (
                    'Recent jobs loaded',
                    '${docs.length}',
                    Icons
                        .receipt_long_outlined,
                    Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ],
              )
            else
              _RaAdminOpsMetricGrid(
                metrics: [
                  (
                    'Completed',
                    '${completed.length}',
                    Icons
                        .task_alt_rounded,
                    raSuccess,
                  ),
                  (
                    'Payment confirmed',
                    '${confirmed.length}',
                    Icons
                        .payments_outlined,
                    raSuccess,
                  ),
                  (
                    'Driver reported',
                    '${reported.length}',
                    Icons
                        .hourglass_top_rounded,
                    raGold,
                  ),
                  (
                    'Not reported',
                    '${unpaid.length}',
                    Icons
                        .payment_outlined,
                    Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  (
                    'Confirmed value',
                    _money(
                      confirmedTotal,
                    ),
                    Icons
                        .account_balance_wallet_outlined,
                    Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  (
                    'Cancellation rate',
                    docs.isEmpty
                        ? '0%'
                        : '${(100 * cancelled / docs.length).toStringAsFixed(1)}%',
                    Icons
                        .cancel_outlined,
                    cancelled == 0
                        ? raSuccess
                        : raGold,
                  ),
                ],
              ),

            if (widget.mode ==
                'operations') ...[
              const SizedBox(
                height: 25,
              ),

              const _RaAdminOpsSectionHeader(
                title:
                    'Complaint follow-ups',
                subtitle:
                    'Overdue reviews requiring administrator attention.',
              ),

              const SizedBox(
                height: 10,
              ),

              const _RaAdminComplaintFollowUps(),

              const SizedBox(
                height: 25,
              ),

              const _RaAdminOpsNotice(
                icon: Icons
                    .info_outline_rounded,
                title:
                    'Operational review only',
                message:
                    'Attention flags are review prompts. They do not automatically identify misconduct and do not change provider assignment or pricing.',
                tone:
                    raBlue,
              ),
            ],

            if (widget.mode ==
                'payments') ...[
              const SizedBox(
                height: 18,
              ),

              _RaAdminPaymentFilter(
                value:
                    attentionOnly,
                onChanged:
                    (value) {
                  setState(() {
                    attentionOnly =
                        value;
                  });
                },
              ),
            ],

            if (widget.mode ==
                'reports') ...[
              const SizedBox(
                height: 25,
              ),

              const _RaAdminOpsSectionHeader(
                title:
                    'Reports',
                subtitle:
                    'Export the currently loaded records or review the loaded service mix.',
              ),

              const SizedBox(
                height: 10,
              ),

              _RaAdminOpsReportCard(
                jobs:
                    docs.length,
                onExport: () {
                  _export(
                    docs,
                  );
                },
              ),

              const SizedBox(
                height: 14,
              ),

              _RaAdminServiceMix(
                docs: docs,
                matches:
                    _matchesService,
              ),
            ],

            if (widget.mode !=
                'reports') ...[
              const SizedBox(
                height: 25,
              ),

              _RaAdminOpsSectionHeader(
                title: widget.mode ==
                        'payments'
                    ? 'Completed payments'
                    : 'Jobs requiring attention',
                subtitle: widget.mode ==
                        'payments'
                    ? attentionOnly
                        ? 'Showing completed jobs without provider payment confirmation.'
                        : 'Showing all completed jobs in the loaded records.'
                    : 'Open a job to inspect status, contact participants and review the timeline.',
              ),

              const SizedBox(
                height: 10,
              ),

              if (shown.isEmpty)
                _RaAdminOpsEmptyState(
                  icon: widget.mode ==
                          'payments'
                      ? Icons
                          .payments_outlined
                      : Icons
                          .verified_outlined,
                  title: widget.mode ==
                          'payments'
                      ? 'No payments need attention'
                      : 'No jobs need attention',
                  message: widget.mode ==
                          'payments'
                      ? 'There are no matching completed payment records in the loaded jobs.'
                      : 'No waiting or stalled jobs currently match the operational thresholds.',
                )
              else
                for (var index = 0;
                    index <
                        shown.length;
                    index++) ...[
                  if (index > 0)
                    const SizedBox(
                      height: 9,
                    ),

                  _RaAdminOpsJobCard(
                    requestId:
                        shown[index].id,
                    data:
                        shown[index].data(),
                    paymentMode:
                        widget.mode ==
                            'payments',
                    statusLabel:
                        _statusLabel,
                    statusTone:
                        _statusTone,
                    ageMinutes:
                        _ageMinutes,
                    amount:
                        _amount,
                    money:
                        _money,
                  ),
                ],
            ],

            if (docs.length ==
                limit) ...[
              const SizedBox(
                height: 18,
              ),

              OutlinedButton.icon(
                onPressed:
                    _loadMore,
                icon: const Icon(
                  Icons
                      .expand_more_rounded,
                ),
                label: Text(
                  'Load 100 more jobs · currently $limit',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RaAdminOpsLoadedDataNotice
    extends StatelessWidget {
  const _RaAdminOpsLoadedDataNotice({
    required this.count,
    required this.limit,
  });

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: .28,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .data_usage_outlined,
            color:
                colors.primary,
            size: 19,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              '$count recent jobs loaded from a maximum of $limit. Metrics and exports below represent only these loaded records, not lifetime totals.',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 8.5,
                height: 1.45,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminOpsMetricGrid
    extends StatelessWidget {
  const _RaAdminOpsMetricGrid({
    required this.metrics,
  });

  final List<
      (
        String,
        String,
        IconData,
        Color
      )> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final columns =
            constraints.maxWidth >=
                    900
                ? 3
                : constraints.maxWidth >=
                        520
                    ? 2
                    : 1;

        final spacing =
            10.0;

        final width =
            columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth -
                        spacing *
                            (columns -
                                1)) /
                    columns;

        return Wrap(
          spacing:
              spacing,
          runSpacing:
              spacing,
          children: [
            for (final metric
                in metrics)
              SizedBox(
                width:
                    width,
                child:
                    _RaAdminOpsMetricCard(
                  label:
                      metric.$1,
                  value:
                      metric.$2,
                  icon:
                      metric.$3,
                  tone:
                      metric.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RaAdminOpsMetricCard
    extends StatelessWidget {
  const _RaAdminOpsMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 108,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
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
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color: tone
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: tone,
              size: 20,
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
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 17,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  label,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    height: 1.3,
                    color: colors
                        .onSurfaceVariant,
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

class _RaAdminOpsSectionHeader
    extends StatelessWidget {
  const _RaAdminOpsSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 15,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.25,
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        Text(
          subtitle,
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 8.6,
            height: 1.4,
            color: colors
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaAdminComplaintFollowUps
    extends StatelessWidget {
  const _RaAdminComplaintFollowUps();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'complaintReviews',
          )
          .limit(100)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const _RaAdminOpsNotice(
            icon:
                Icons.report_problem_outlined,
            title:
                'Complaint reviews unavailable',
            message:
                'RoadAssist could not load complaint follow-up records.',
            tone:
                raDanger,
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final now =
            DateTime.now();

        final overdue =
            snapshot.data!.docs.where(
          (document) {
            final data =
                document.data();

            final dueAt =
                (data['dueAt']
                        as Timestamp?)
                    ?.toDate();

            return data['status'] ==
                    'under_review' &&
                dueAt != null &&
                dueAt.isBefore(
                  now,
                );
          },
        ).toList();

        if (overdue.isEmpty) {
          return const _RaAdminOpsEmptyState(
            icon: Icons
                .check_circle_outline_rounded,
            title:
                'No overdue complaint reviews',
            message:
                'No loaded complaint follow-up is currently past its review due time.',
          );
        }

        return Column(
          children: [
            for (var index = 0;
                index <
                    overdue.length;
                index++) ...[
              if (index > 0)
                const SizedBox(
                  height: 8,
                ),

              _RaAdminComplaintFollowUpCard(
                requestId:
                    overdue[index].id,
                data:
                    overdue[index].data(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RaAdminComplaintFollowUpCard
    extends StatelessWidget {
  const _RaAdminComplaintFollowUpCard({
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final priority =
        data['priority']
                ?.toString() ??
            'normal';

    final dueAt =
        (data['dueAt']
                as Timestamp?)
            ?.toDate()
            .toLocal();

    final due =
        dueAt == null
            ? 'Due time unavailable'
            : '${dueAt.day.toString().padLeft(2, '0')}/${dueAt.month.toString().padLeft(2, '0')}/${dueAt.year}';

    return Material(
      color: theme.brightness ==
              Brightness.dark
          ? const Color(
              0xFF0D1D2B,
            )
          : colors.surface,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        side: BorderSide(
          color: raDanger
              .withValues(
            alpha: .22,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          push(
            context,
            _AdminComplaintScreen(
              requestId:
                  requestId,
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            13,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: raDanger
                      .withValues(
                    alpha: .07,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .assignment_late_outlined,
                  color:
                      raDanger,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Case $requestId',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Priority: $priority • Due $due',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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

class _RaAdminPaymentFilter
    extends StatelessWidget {
  const _RaAdminPaymentFilter({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 12,
        vertical: 4,
      ),
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
          17,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: SwitchListTile(
        contentPadding:
            EdgeInsets.zero,
        title: Text(
          'Only payments needing confirmation',
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 10,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Hide completed jobs after provider receipt is confirmed.',
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 8,
            color: colors
                .onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged:
            onChanged,
      ),
    );
  }
}

class _RaAdminOpsJobCard
    extends StatelessWidget {
  const _RaAdminOpsJobCard({
    required this.requestId,
    required this.data,
    required this.paymentMode,
    required this.statusLabel,
    required this.statusTone,
    required this.ageMinutes,
    required this.amount,
    required this.money,
  });

  final String requestId;

  final Map<String, dynamic>
      data;

  final bool paymentMode;

  final String Function(String)
      statusLabel;

  final RaTone Function(String)
      statusTone;

  final int Function(
    Map<String, dynamic>, {
    bool fromCreatedAt,
  }) ageMinutes;

  final int Function(
    Map<String, dynamic>,
  ) amount;

  final String Function(num)
      money;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final status =
        data['status']
                ?.toString() ??
            'unknown';

    final driver =
        data['driverName']
                ?.toString() ??
            'Driver';

    final provider =
        data['providerName']
                ?.toString() ??
            'Unassigned';

    final location =
        data['locationLabel']
                ?.toString() ??
            data['location']
                ?.toString() ??
            'Location unavailable';

    final lastUpdateAge =
        ageMinutes(data);

    final paymentConfirmed =
        data['providerConfirmedPayment'] ==
            true;

    final driverReported =
        data['driverReportedPayment'] ==
            true;

    final paymentLabel =
        paymentConfirmed
            ? 'Provider confirmed receipt'
            : driverReported
                ? 'Driver reports paid; confirmation pending'
                : 'Payment not reported';

    final value =
        amount(data);

    return Material(
      color: theme.brightness ==
              Brightness.dark
          ? const Color(
              0xFF0D1D2B,
            )
          : colors.surface,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        side: BorderSide(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          push(
            context,
            paymentMode
                ? InvoiceScreen(
                    requestId:
                        requestId,
                  )
                : AdminJobMonitorScreen(
                    requestId:
                        requestId,
                  ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Row(
                children: [
                  ProfileInitials(
                    name:
                        driver,
                    radius:
                        20,
                  ),

                  const SizedBox(
                    width: 10,
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
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize:
                                10.5,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          provider,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize:
                                8,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  StatusPill(
                    label:
                        statusLabel(
                      status,
                    ),
                    tone:
                        statusTone(
                      status,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              _RaAdminOpsInfoRow(
                icon: Icons
                    .car_repair_outlined,
                text:
                    requestIssueLabel(
                  data,
                ),
              ),

              _RaAdminOpsInfoRow(
                icon: Icons
                    .location_on_outlined,
                text:
                    location,
              ),

              _RaAdminOpsInfoRow(
                icon: Icons
                    .schedule_outlined,
                text:
                    lastUpdateAge <=
                            0
                        ? 'Last update time unavailable'
                        : 'Last activity $lastUpdateAge min ago',
              ),

              if (paymentMode)
                _RaAdminOpsInfoRow(
                  icon: Icons
                      .payments_outlined,
                  text:
                      '$paymentLabel${value > 0 ? ' • ${money(value)}' : ''}',
                ),

              const SizedBox(
                height: 9,
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .end,
                children: [
                  Text(
                    paymentMode
                        ? 'Open invoice'
                        : 'Monitor job',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 8,
                      fontWeight:
                          FontWeight
                              .w700,
                      color: colors
                          .primary,
                    ),
                  ),

                  const SizedBox(
                    width: 3,
                  ),

                  Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 16,
                    color: colors
                        .primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaAdminOpsInfoRow
    extends StatelessWidget {
  const _RaAdminOpsInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                colors.primary,
          ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow:
                  TextOverflow
                      .ellipsis,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 8.2,
                height: 1.4,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminOpsReportCard
    extends StatelessWidget {
  const _RaAdminOpsReportCard({
    required this.jobs,
    required this.onExport,
  });

  final int jobs;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
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
          19,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              Icons
                  .download_outlined,
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
                  'Loaded job report',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  '$jobs records will be exported as CSV.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          FilledButton.icon(
            onPressed:
                jobs == 0
                    ? null
                    : onExport,
            icon: const Icon(
              Icons
                  .file_download_outlined,
            ),
            label: const Text(
              'Export',
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminServiceMix
    extends StatelessWidget {
  const _RaAdminServiceMix({
    required this.docs,
    required this.matches,
  });

  final List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      docs;

  final bool Function(
    Map<String, dynamic>,
    String,
  ) matches;

  static const services = [
    'General Mechanic',
    'Vehicle Towing',
    'Flat Tyre',
    'Battery Jumpstart',
  ];

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final service
          in services)
        service: docs
            .where(
              (document) =>
                  matches(
                document.data(),
                service,
              ),
            )
            .length,
    };

    final max =
        counts.values.fold<int>(
      0,
      (
        current,
        value,
      ) =>
          value >
                  current
              ? value
              : current,
    );

    return _RaAdminOpsSurface(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          Text(
            'SERVICE MIX',
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 7.7,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: .7,
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          for (var index = 0;
              index <
                  services.length;
              index++) ...[
            if (index > 0)
              const SizedBox(
                height: 12,
              ),

            _RaAdminServiceMixRow(
              service:
                  services[index],
              value:
                  counts[
                        services[index]
                      ] ??
                      0,
              max:
                  max,
            ),
          ],
        ],
      ),
    );
  }
}

class _RaAdminServiceMixRow
    extends StatelessWidget {
  const _RaAdminServiceMixRow({
    required this.service,
    required this.value,
    required this.max,
  });

  final String service;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final progress =
        max <= 0
            ? 0.0
            : value / max;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                service,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 8.7,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            Text(
              '$value',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 9,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 6,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            999,
          ),
          child:
              LinearProgressIndicator(
            value:
                progress,
            minHeight:
                6,
            backgroundColor: colors
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaAdminOpsSurface
    extends StatelessWidget {
  const _RaAdminOpsSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : theme
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _RaAdminOpsNotice
    extends StatelessWidget {
  const _RaAdminOpsNotice({
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
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color: tone
            .withValues(
          alpha: .07,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: tone
              .withValues(
            alpha: .17,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            size: 20,
            color: tone,
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
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.5,
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
    );
  }
}

class _RaAdminOpsEmptyState
    extends StatelessWidget {
  const _RaAdminOpsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        24,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: .22,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 30,
            color:
                colors.primary,
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize: 8.5,
              height: 1.4,
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// APP SETTINGS
// ============================================================================

class _AdminSettingsPanel
    extends StatefulWidget {
  const _AdminSettingsPanel();

  @override
  State<_AdminSettingsPanel> createState() =>
      _AdminSettingsPanelState();
}

class _AdminSettingsPanelState
    extends State<_AdminSettingsPanel> {
  final notice =
      TextEditingController();

  final coverage =
      TextEditingController();

  final services =
      <String>{
    'General Mechanic',
    'Vehicle Towing',
    'Flat Tyre',
    'Battery Jumpstart',
  };

  bool maintenance = false;

  bool loading = true;
  bool busy = false;

  String? feedback;
  bool feedbackError = false;

  static const availableServices = [
    'General Mechanic',
    'Vehicle Towing',
    'Flat Tyre',
    'Battery Jumpstart',
  ];

  @override
  void initState() {
    super.initState();

    unawaited(
      _load(),
    );
  }

  @override
  void dispose() {
    notice.dispose();
    coverage.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot =
          await FirebaseFirestore
              .instance
              .collection(
                'appSettings',
              )
              .doc(
                'operations',
              )
              .get();

      final data =
          snapshot.data();

      if (data != null) {
        notice.text =
            data['notice']
                    ?.toString() ??
                '';

        coverage.text =
            data['coverage']
                    ?.toString() ??
                '';

        final storedServices =
            (data['enabledServices']
                        as List<dynamic>? ??
                    const [])
                .whereType<String>()
                .where(
                  (service) =>
                      service
                          .trim()
                          .isNotEmpty,
                )
                .toList();

        if (storedServices.isNotEmpty) {
          services
            ..clear()
            ..addAll(
              storedServices,
            );
        }

        maintenance =
            data['maintenance'] ==
                true;
      }
    } catch (_) {
      feedback =
          'Unable to load current settings.';

      feedbackError =
          true;
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (busy) {
      return;
    }

    final reason =
        await _adminReason(
      context,
      'Reason for changing app settings',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      busy = true;
      feedback = null;
      feedbackError = false;
    });

    try {
      await AdminService()
          .saveSettings(
        maintenance:
            maintenance,
        notice:
            notice.text.trim(),
        coverage:
            coverage.text.trim(),
        services:
            services.toList(),
        reason:
            reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        feedback =
            'Settings saved with an admin audit record.';

        feedbackError =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        feedback =
            'Settings were not saved. Super-admin permission is required.';

        feedbackError =
            true;
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final colors =
        Theme.of(context)
            .colorScheme;

    return ListView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        32,
      ),
      children: [
        _RaAdminSettingsHero(
          maintenance:
              maintenance,
        ),

        const SizedBox(
          height: 24,
        ),

        const _RaAdminOpsSectionHeader(
          title:
              'Service availability',
          subtitle:
              'Control whether new assistance requests can be created and which RoadAssist services are available.',
        ),

        const SizedBox(
          height: 10,
        ),

        _RaAdminOpsSurface(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                secondary: Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: (maintenance
                            ? raDanger
                            : raSuccess)
                        .withValues(
                      alpha: .08,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    maintenance
                        ? Icons
                            .pause_circle_outline_rounded
                        : Icons
                            .check_circle_outline_rounded,
                    color: maintenance
                        ? raDanger
                        : raSuccess,
                  ),
                ),
                title: Text(
                  'Pause new assistance requests',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                subtitle: Text(
                  maintenance
                      ? 'Maintenance mode is selected.'
                      : 'New assistance requests remain enabled.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                value:
                    maintenance,
                onChanged: busy
                    ? null
                    : (value) {
                        setState(
                          () {
                            maintenance =
                                value;
                          },
                        );
                      },
              ),

              const SizedBox(
                height: 5,
              ),

              const _RaAdminOpsNotice(
                icon: Icons
                    .info_outline_rounded,
                title:
                    'Existing jobs remain accessible',
                message:
                    'Maintenance pauses new requests only. Existing jobs, messages and invoices remain available.',
                tone:
                    raBlue,
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        const _RaAdminOpsSectionHeader(
          title:
              'Public information',
          subtitle:
              'These values can be displayed to RoadAssist users. Do not include personal or private information.',
        ),

        const SizedBox(
          height: 10,
        ),

        _RaAdminOpsSurface(
          child: Column(
            children: [
              TextField(
                controller:
                    notice,
                enabled:
                    !busy,
                maxLength:
                    300,
                minLines:
                    2,
                maxLines:
                    4,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Public service notice',
                  alignLabelWithHint:
                      true,
                  prefixIcon:
                      Padding(
                    padding:
                        EdgeInsets.only(
                      bottom: 42,
                    ),
                    child: Icon(
                      Icons
                          .campaign_outlined,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              TextField(
                controller:
                    coverage,
                enabled:
                    !busy,
                maxLength:
                    300,
                minLines:
                    2,
                maxLines:
                    4,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Coverage description',
                  helperText:
                      'Informational only; this does not create a geofence.',
                  alignLabelWithHint:
                      true,
                  prefixIcon:
                      Padding(
                    padding:
                        EdgeInsets.only(
                      bottom: 42,
                    ),
                    child: Icon(
                      Icons
                          .map_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        const _RaAdminOpsSectionHeader(
          title:
              'Enabled services',
          subtitle:
              'Service availability applies to new assistance requests.',
        ),

        const SizedBox(
          height: 10,
        ),

        _RaAdminOpsSurface(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service
                  in availableServices)
                FilterChip(
                  label:
                      Text(
                    service,
                  ),
                  selected:
                      services.contains(
                    service,
                  ),
                  onSelected: busy
                      ? null
                      : (selected) {
                          setState(
                            () {
                              if (selected) {
                                services.add(
                                  service,
                                );
                              } else {
                                services.remove(
                                  service,
                                );
                              }
                            },
                          );
                        },
                ),
            ],
          ),
        ),

        if (feedback !=
            null) ...[
          const SizedBox(
            height: 13,
          ),

          _RaAdminOpsNotice(
            icon: feedbackError
                ? Icons
                    .error_outline_rounded
                : Icons
                    .check_circle_outline_rounded,
            title: feedbackError
                ? 'Settings not saved'
                : 'Settings updated',
            message:
                feedback!,
            tone: feedbackError
                ? raDanger
                : raSuccess,
          ),
        ],

        const SizedBox(
          height: 18,
        ),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ||
                    services.isEmpty
                ? null
                : _save,
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .save_outlined,
                  ),
            label: Text(
              busy
                  ? 'Saving...'
                  : 'Save with Audit Record',
            ),
          ),
        ),
      ],
    );
  }
}

class _RaAdminSettingsHero
    extends StatelessWidget {
  const _RaAdminSettingsHero({
    required this.maintenance,
  });

  final bool maintenance;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(
                    0xFF0A497F,
                  ),
                  Color(
                    0xFF075A68,
                  ),
                ]
              : const [
                  Color(
                    0xFF075BA8,
                  ),
                  Color(
                    0xFF078C7E,
                  ),
                ],
        ),
        borderRadius:
            BorderRadius.circular(
          23,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: .13,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child:
                const Icon(
              Icons
                  .settings_outlined,
              color:
                  Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'App operations',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color:
                        Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  maintenance
                      ? 'New assistance requests are configured to pause.'
                      : 'RoadAssist is configured to accept new assistance requests.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors
                        .white70,
                    fontSize: 8.7,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          StatusPill(
            label: maintenance
                ? 'MAINTENANCE'
                : 'ACTIVE',
            tone: maintenance
                ? RaTone.warning
                : RaTone.success,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADMIN TEAM
// ============================================================================

class _AdminTeamPanel
    extends StatelessWidget {
  const _AdminTeamPanel();

  String _roleLabel(
    String role,
  ) {
    return switch (role) {
      'super_admin' =>
        'Super Admin',
      'reviewer' =>
        'Provider Reviewer',
      'support' =>
        'Support',
      _ => role
          .replaceAll(
            '_',
            ' ',
          )
          .trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'adminAccess',
          )
          .limit(100)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const Padding(
            padding:
                EdgeInsets.all(
              20,
            ),
            child:
                _RaAdminOpsNotice(
              icon: Icons
                  .lock_outline_rounded,
              title:
                  'Admin team unavailable',
              message:
                  'Super-admin permission is required to read administrator access records.',
              tone:
                  raDanger,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final admins =
            snapshot.data!.docs
                .toList();

        admins.sort(
          (
            first,
            second,
          ) {
            final firstEmail =
                first.data()['email']
                        ?.toString()
                        .toLowerCase() ??
                    first.id;

            final secondEmail =
                second.data()['email']
                        ?.toString()
                        .toLowerCase() ??
                    second.id;

            return firstEmail
                .compareTo(
              secondEmail,
            );
          },
        );

        final active =
            admins.where(
          (document) =>
              document.data()['enabled'] ==
              true,
        ).length;

        return ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            32,
          ),
          children: [
            _RaAdminTeamHero(
              total:
                  admins.length,
              active:
                  active,
            ),

            const SizedBox(
              height: 17,
            ),

            const _RaAdminOpsNotice(
              icon: Icons
                  .admin_panel_settings_outlined,
              title:
                  'Owner-provisioned access',
              message:
                  'There is no public admin registration. Admin access must be granted or revoked through the project owner provisioning process.',
              tone:
                  raBlue,
            ),

            const SizedBox(
              height: 23,
            ),

            const _RaAdminOpsSectionHeader(
              title:
                  'Permission model',
              subtitle:
                  'Administrator roles have different responsibilities inside the RoadAssist management workspace.',
            ),

            const SizedBox(
              height: 10,
            ),

            const _RaAdminPermissionCard(),

            const SizedBox(
              height: 23,
            ),

            _RaAdminOpsSectionHeader(
              title:
                  'Admin accounts',
              subtitle:
                  '${admins.length} access ${admins.length == 1 ? 'record' : 'records'} loaded.',
            ),

            const SizedBox(
              height: 10,
            ),

            if (admins.isEmpty)
              const _RaAdminOpsEmptyState(
                icon: Icons
                    .admin_panel_settings_outlined,
                title:
                    'No admin access records',
                message:
                    'No administrator access records were returned.',
              )
            else
              for (var index = 0;
                  index <
                      admins.length;
                  index++) ...[
                if (index > 0)
                  const SizedBox(
                    height: 8,
                  ),

                _RaAdminTeamMemberCard(
                  uid:
                      admins[index].id,
                  data:
                      admins[index].data(),
                  roleLabel:
                      _roleLabel,
                ),
              ],
          ],
        );
      },
    );
  }
}

class _RaAdminTeamHero
    extends StatelessWidget {
  const _RaAdminTeamHero({
    required this.total,
    required this.active,
  });

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(
                    0xFF0A497F,
                  ),
                  Color(
                    0xFF075A68,
                  ),
                ]
              : const [
                  Color(
                    0xFF075BA8,
                  ),
                  Color(
                    0xFF078C7E,
                  ),
                ],
        ),
        borderRadius:
            BorderRadius.circular(
          23,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: .13,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child:
                const Icon(
              Icons
                  .groups_2_outlined,
              color:
                  Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Admin team',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color:
                        Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$active active of $total loaded administrator access records',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors
                        .white70,
                    fontSize: 8.5,
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

class _RaAdminPermissionCard
    extends StatelessWidget {
  const _RaAdminPermissionCard();

  @override
  Widget build(BuildContext context) {
    return _RaAdminOpsSurface(
      child: Column(
        children: const [
          _RaAdminPermissionRow(
            icon: Icons
                .security_outlined,
            title:
                'Super Admin',
            description:
                'Settings, users, verification and cases.',
          ),

          Divider(),

          _RaAdminPermissionRow(
            icon: Icons
                .verified_user_outlined,
            title:
                'Provider Reviewer',
            description:
                'Provider documents and verification decisions.',
          ),

          Divider(),

          _RaAdminPermissionRow(
            icon: Icons
                .support_agent_outlined,
            title:
                'Support',
            description:
                'Complaints, jobs and payment monitoring.',
          ),
        ],
      ),
    );
  }
}

class _RaAdminPermissionRow
    extends StatelessWidget {
  const _RaAdminPermissionRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .07,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
                  colors.primary,
              size: 18,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  description,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.9,
                    color: colors
                        .onSurfaceVariant,
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

class _RaAdminTeamMemberCard
    extends StatelessWidget {
  const _RaAdminTeamMemberCard({
    required this.uid,
    required this.data,
    required this.roleLabel,
  });

  final String uid;

  final Map<String, dynamic>
      data;

  final String Function(String)
      roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final email =
        data['email']
                ?.toString()
                .trim() ??
            '';

    final role =
        data['role']
                ?.toString() ??
            'super_admin';

    final enabled =
        data['enabled'] ==
            true;

    final display =
        email.isEmpty
            ? uid
            : email;

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
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
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color: (enabled
                      ? colors.primary
                      : colors
                          .onSurfaceVariant)
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              Icons
                  .admin_panel_settings_outlined,
              color: enabled
                  ? colors.primary
                  : colors
                      .onSurfaceVariant,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  display,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.7,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  roleLabel(role),
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          StatusPill(
            label: enabled
                ? 'Active'
                : 'Revoked',
            tone: enabled
                ? RaTone.success
                : RaTone.danger,
          ),
        ],
      ),
    );
  }
}