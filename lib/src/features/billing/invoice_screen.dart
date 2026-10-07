part of '../../screens.dart';

class InvoiceScreen
    extends StatefulWidget {
  const InvoiceScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<InvoiceScreen> createState() =>
      _InvoiceScreenState();
}

class _InvoiceScreenState
    extends State<InvoiceScreen> {
  late final Stream<
          DocumentSnapshot<
              Map<String, dynamic>>>
      request;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    request = RequestService()
        .watchRequest(
      widget.requestId,
    );
  }

  Future<void> record(
    String method,
  ) async {
    setState(() {
      saving = true;
    });

    try {
      await RequestService()
          .recordPayment(
        widget.requestId,
        method,
      );
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
          saving = false;
        });
      }
    }
  }

  String money(
    dynamic value,
  ) {
    final amount =
        (value as num?)?.toInt() ??
            0;

    final digits =
        amount.abs().toString();

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

    return 'Rs. ${amount < 0 ? '-' : ''}${buffer.toString()}';
  }

  Widget _paymentStatus(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final providerConfirmed =
        data['providerConfirmedPayment'] ==
            true;

    final driverReported =
        data['driverReportedPayment'] ==
            true;

    final color = providerConfirmed
        ? raSuccess
        : driverReported
            ? raGold
            : colors
                .onSurfaceVariant;

    final icon = providerConfirmed
        ? Icons
            .verified_outlined
        : driverReported
            ? Icons
                .schedule_outlined
            : Icons
                .payments_outlined;

    final title = providerConfirmed
        ? 'Payment confirmed'
        : driverReported
            ? 'Payment awaiting provider confirmation'
            : 'Payment not recorded';

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(
          alpha: .08,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: color.withValues(
            alpha: .22,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: color
                  .withValues(
                alpha: .12,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              icon,
              color: color,
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
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (data['paymentMethod']
                    is String) ...[
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Method: ${data['paymentMethod']}',
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ],
            ),
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
        title: const Text(
          'Service Invoice',
        ),
      ),

      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: request,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons
                  .cloud_off_outlined,
              title:
                  'Unable to load invoice',
              message:
                  'Check your connection and try again.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data();

          if (data == null ||
              data['status'] !=
                  'completed') {
            return const EmptyState(
              icon: Icons
                  .receipt_long_outlined,
              title:
                  'Invoice not available yet',
              message:
                  'The final invoice becomes available after service completion.',
            );
          }

          final approved =
              (data['estimatedCost']
                          as num?)
                      ?.toInt() ??
                  0;

          final total =
              (data['finalCost']
                          as num?)
                      ?.toInt() ??
                  approved;

          final uid =
              FirebaseAuth
                  .instance
                  .currentUser
                  ?.uid;

          final provider =
              uid ==
                  data['providerId'];

          final driver =
              uid ==
                  data['driverId'];

          final serviceFee =
              data['serviceFee'];

          final travelFee =
              data['dispatchFee'];

          final extraFee =
              data['extraFee'];

          return ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              RaSpace.xxxl,
            ),
            children: [
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
                    colors: [
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
                          width: 52,
                          height: 52,
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  .14,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              17,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .receipt_long_outlined,
                            color:
                                Colors.white,
                            size:
                                27,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                10,
                            vertical: 6,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  .14,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              999,
                            ),
                          ),
                          child:
                              const Text(
                            'COMPLETED',
                            style:
                                TextStyle(
                              color: Colors
                                  .white,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              fontSize:
                                  11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    Text(
                      'Final service invoice',
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      money(total),
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Job ${widget.requestId}',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.xl,
              ),

              Text(
                'Service details',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _InvoiceCard(
                children: [
                  _InvoiceRow(
                    icon: Icons
                        .person_outline_rounded,
                    label:
                        'Provider',
                    value:
                        data['providerName']
                                as String? ??
                            'Not recorded',
                  ),
                  _InvoiceRow(
                    icon: Icons
                        .directions_car_outlined,
                    label:
                        'Vehicle',
                    value:
                        data['modelYear']
                                as String? ??
                            'Not recorded',
                  ),
                  _InvoiceRow(
                    icon: Icons
                        .pin_outlined,
                    label:
                        'Registration',
                    value:
                        data['registration']
                                as String? ??
                            'Not recorded',
                  ),
                  _InvoiceRow(
                    icon: Icons
                        .car_repair_outlined,
                    label:
                        'Reported problem',
                    value:
                        requestIssueLabel(
                      data,
                    ),
                  ),
                  if (data['providerDiagnosis']
                      is String)
                    _InvoiceRow(
                      icon: Icons
                          .engineering_outlined,
                      label:
                          'Diagnosis / approved work',
                      value:
                          data['providerDiagnosis']
                              as String,
                    ),
                ],
              ),

              const SizedBox(
                height: RaSpace.xxl,
              ),

              Text(
                'Price breakdown',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _InvoiceCard(
                children: [
                  _InvoiceRow(
                    icon: Icons
                        .build_outlined,
                    label:
                        'Service / labour',
                    value:
                        money(
                      serviceFee,
                    ),
                  ),
                  _InvoiceRow(
                    icon: Icons
                        .route_outlined,
                    label:
                        'Travel',
                    value:
                        money(
                      travelFee,
                    ),
                  ),
                  _InvoiceRow(
                    icon: Icons
                        .add_card_outlined,
                    label:
                        'Parts / other approved charges',
                    value:
                        money(
                      extraFee,
                    ),
                  ),
                  if (total <
                      approved)
                    _InvoiceRow(
                      icon: Icons
                          .discount_outlined,
                      label:
                          'Discount',
                      value:
                          money(
                        approved -
                            total,
                      ),
                    ),
                  _InvoiceRow(
                    icon: Icons
                        .payments_outlined,
                    label:
                        'Final total',
                    value:
                        money(total),
                    strong: true,
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.xxl,
              ),

              Text(
                'Payment',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              _paymentStatus(
                context,
                data,
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
                          .info_outline_rounded,
                      color: colors
                          .primary,
                      size: 19,
                    ),
                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    Expanded(
                      child: Text(
                        'Cash and external payments are recorded manually. RoadAssist does not process the payment inside the app.',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height:
                              1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (driver &&
                  data['driverReportedPayment'] !=
                      true) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),

                Text(
                  'Only record payment after you have actually paid the provider.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            saving
                                ? null
                                : () =>
                                    record(
                                      'cash',
                                    ),
                        icon:
                            const Icon(
                          Icons
                              .payments_outlined,
                        ),
                        label:
                            const Text(
                          'Paid Cash',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width:
                          RaSpace.sm,
                    ),
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            saving
                                ? null
                                : () =>
                                    record(
                                      'external',
                                    ),
                        icon:
                            const Icon(
                          Icons
                              .open_in_new_rounded,
                        ),
                        label:
                            const Text(
                          'Paid Externally',
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (provider &&
                  data['driverReportedPayment'] ==
                      true &&
                  data['providerConfirmedPayment'] !=
                      true) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed:
                        saving
                            ? null
                            : () =>
                                record(
                                  data['paymentMethod']
                                          as String? ??
                                      'external',
                                ),
                    icon: const Icon(
                      Icons
                          .verified_outlined,
                    ),
                    label: const Text(
                      'Confirm Payment Received',
                    ),
                  ),
                ),
              ],

              if (saving) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                const LinearProgressIndicator(
                  minHeight: 3,
                ),
              ],

              const SizedBox(
                height: RaSpace.xxl,
              ),

              ServiceWarranty(
                requestId:
                    widget.requestId,
                job: data,
              ),

              if (driver) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () =>
                        push(
                      context,
                      DisputeScreen(
                        requestId:
                            widget
                                .requestId,
                        sameProblem:
                            true,
                      ),
                    ),
                    icon: const Icon(
                      Icons
                          .build_circle_outlined,
                    ),
                    label: const Text(
                      'Same Problem Again / Warranty Review',
                    ),
                  ),
                ),
              ],

              if (driver ||
                  provider) ...[
                const SizedBox(
                  height: RaSpace.sm,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          colors.error,
                    ),
                    onPressed: () =>
                        push(
                      context,
                      DisputeScreen(
                        requestId:
                            widget
                                .requestId,
                      ),
                    ),
                    icon: const Icon(
                      Icons
                          .report_problem_outlined,
                    ),
                    label: Text(
                      driver
                          ? 'Report a Problem / View Report'
                          : 'View Service Problem Report',
                    ),
                  ),
                ),
              ],

              if (data['workflowVersion'] ==
                  2) ...[
                const SizedBox(
                  height: RaSpace.xxl,
                ),
                _InvoiceApprovalHistory(
                  requestId:
                      widget.requestId,
                  selectedQuoteId:
                      data['selectedQuoteId']
                          as String?,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceCard
    extends StatelessWidget {
  const _InvoiceCard({
    required this.children,
  });

  final List<_InvoiceRow>
      children;

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
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
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

class _InvoiceRow
    extends StatelessWidget {
  const _InvoiceRow({
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

class _InvoiceApprovalHistory
    extends StatefulWidget {
  const _InvoiceApprovalHistory({
    required this.requestId,
    this.selectedQuoteId,
  });

  final String requestId;
  final String? selectedQuoteId;

  @override
  State<_InvoiceApprovalHistory>
      createState() =>
          _InvoiceApprovalHistoryState();
}

class _InvoiceApprovalHistoryState
    extends State<_InvoiceApprovalHistory> {
  late final Stream<
          QuerySnapshot<
              Map<String, dynamic>>>
      revisions;

  late final Stream<
          QuerySnapshot<
              Map<String, dynamic>>>
      decisions;

  late final Stream<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      initialQuote;

  @override
  void initState() {
    super.initState();

    final ref =
        FirebaseFirestore.instance
            .collection('requests')
            .doc(widget.requestId);

    revisions = ref
        .collection('repairQuotes')
        .snapshots();

    decisions = ref
        .collection('repairDecisions')
        .snapshots();

    initialQuote =
        widget.selectedQuoteId ==
                null
            ? null
            : ref
                .collection('quotes')
                .doc(
                  widget
                      .selectedQuoteId,
                )
                .snapshots();
  }

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
          'Quote & approval history',
          style: theme
              .textTheme.titleLarge
              ?.copyWith(
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          'Rejected or unapproved repair proposals are not added to the final bill.',
          style: theme
              .textTheme.bodySmall,
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        if (initialQuote != null)
          StreamBuilder<
              DocumentSnapshot<
                  Map<String,
                      dynamic>>>(
            stream: initialQuote,
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot
                  .hasError) {
                return const InlineMessage(
                  text:
                      'Could not load the original quote.',
                  error: true,
                );
              }

              final quote =
                  snapshot.data
                      ?.data();

              if (quote == null) {
                return const LinearProgressIndicator(
                  minHeight: 3,
                );
              }

              return Container(
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
                    16,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Original approved ${quote['quoteType'] == 'inspection' ? 'inspection' : 'service'} offer',
                      style: theme
                          .textTheme
                          .labelLarge
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
                      'Rs. ${quote['total']}',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        color:
                            colors.primary,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    if ((quote['notes']
                                as String? ??
                            '')
                        .isNotEmpty) ...[
                      const SizedBox(
                        height:
                            RaSpace.sm,
                      ),
                      Text(
                        'Included work / exclusions: ${quote['notes']}',
                        style: theme
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

        if (initialQuote !=
            null)
          const SizedBox(
            height: RaSpace.md,
          ),

        StreamBuilder<
            QuerySnapshot<
                Map<String,
                    dynamic>>>(
          stream: decisions,
          builder: (
            context,
            decisionSnapshot,
          ) {
            return StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream: revisions,
              builder: (
                context,
                revisionSnapshot,
              ) {
                if (revisionSnapshot
                        .hasError ||
                    decisionSnapshot
                        .hasError) {
                  return const InlineMessage(
                    text:
                        'Could not load approval history.',
                    error: true,
                  );
                }

                if (!revisionSnapshot
                        .hasData ||
                    !decisionSnapshot
                        .hasData) {
                  return const LinearProgressIndicator(
                    minHeight: 3,
                  );
                }

                final outcomes = {
                  for (final decision
                      in decisionSnapshot
                          .data!.docs)
                    decision.id:
                        decision.data(),
                };

                final entries =
                    revisionSnapshot
                        .data!.docs
                        .toList()
                      ..sort(
                        (
                          first,
                          second,
                        ) {
                          final firstTime =
                              first.data()[
                                      'createdAt']
                                  as Timestamp?;

                          final secondTime =
                              second.data()[
                                      'createdAt']
                                  as Timestamp?;

                          if (firstTime ==
                                  null ||
                              secondTime ==
                                  null) {
                            return 0;
                          }

                          return firstTime
                              .compareTo(
                            secondTime,
                          );
                        },
                      );

                if (entries.isEmpty) {
                  return Container(
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
                        alpha: .4,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                    child: const Text(
                      'No repair revisions were proposed.',
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final entry
                        in entries) ...[
                      Builder(
                        builder:
                            (context) {
                          final revision =
                              entry
                                  .data();

                          final decision =
                              outcomes[
                                  entry
                                      .id];

                          final outcome =
                              decision?[
                                      'decision']
                                  as String? ??
                                  'not approved';

                          final timestamp =
                              (decision?[
                                          'createdAt']
                                      as Timestamp?) ??
                                  revision[
                                          'createdAt']
                                      as Timestamp?;

                          final date =
                              timestamp
                                  ?.toDate()
                                  .toLocal();

                          final color =
                              outcome ==
                                      'approved'
                                  ? raSuccess
                                  : outcome ==
                                          'rejected'
                                      ? colors
                                          .error
                                      : raGold;

                          return Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets
                                    .all(
                              RaSpace
                                  .md,
                            ),
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .surface,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                17,
                              ),
                              border:
                                  Border.all(
                                color: color
                                    .withValues(
                                  alpha:
                                      .22,
                                ),
                              ),
                            ),
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      outcome ==
                                              'approved'
                                          ? Icons
                                              .check_circle_outline_rounded
                                          : outcome ==
                                                  'rejected'
                                              ? Icons
                                                  .cancel_outlined
                                              : Icons
                                                  .schedule_outlined,
                                      color:
                                          color,
                                    ),
                                    const SizedBox(
                                      width:
                                          RaSpace
                                              .sm,
                                    ),
                                    Expanded(
                                      child:
                                          Text(
                                        outcome
                                            .replaceAll(
                                              '_',
                                              ' ',
                                            )
                                            .toUpperCase(),
                                        style: theme
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                          color:
                                              color,
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height:
                                      RaSpace
                                          .sm,
                                ),
                                Text(
                                  'Rs. ${revision['previousTotal']} → Rs. ${revision['total']}',
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
                                  height: 5,
                                ),
                                Text(
                                  '${revision['diagnosisAndWork']}',
                                  style: theme
                                      .textTheme
                                      .bodyMedium,
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Reason: ${revision['changeReason'] ?? 'Not recorded for this older revision'}',
                                  style: theme
                                      .textTheme
                                      .bodySmall,
                                ),
                                if (date !=
                                    null) ...[
                                  const SizedBox(
                                    height:
                                        4,
                                  ),
                                  Text(
                                    date
                                        .toString()
                                        .split(
                                          '.',
                                        )
                                        .first,
                                    style: theme
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      color: colors
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                RevisionEvidencePhotos(
                                  photos:
                                      List<String>.from(
                                    revision['evidencePhotoData']
                                            as List? ??
                                        [],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
      ],
    );
  }
}