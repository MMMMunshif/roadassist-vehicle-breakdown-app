part of '../../screens.dart';

class InvoiceScreen extends StatefulWidget {
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
      DocumentSnapshot<Map<String, dynamic>>> request;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    request = RequestService().watchRequest(
      widget.requestId,
    );
  }

  Future<void> record(
    String method,
  ) async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      await RequestService().recordPayment(
        widget.requestId,
        method,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
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
    int value,
  ) {
    final source =
        value.abs().toString();

    final output =
        StringBuffer();

    for (var index = 0;
        index < source.length;
        index++) {
      if (index > 0 &&
          (source.length - index) %
                  3 ==
              0) {
        output.write(',');
      }

      output.write(
        source[index],
      );
    }

    return 'Rs. ${value < 0 ? '-' : ''}${output.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Service Invoice',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
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
            return const Padding(
              padding:
                  EdgeInsets.all(20),
              child: EmptyState(
                icon:
                    Icons.cloud_off_outlined,
                title:
                    'Unable to load invoice',
                message:
                    'Reconnect to the internet and try again.',
              ),
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

          if (data == null) {
            return const Padding(
              padding:
                  EdgeInsets.all(20),
              child: EmptyState(
                icon:
                    Icons.receipt_long_outlined,
                title:
                    'Invoice unavailable',
                message:
                    'This service record could not be found.',
              ),
            );
          }

          if (data['status'] !=
              'completed') {
            return const Padding(
              padding:
                  EdgeInsets.all(20),
              child: EmptyState(
                icon:
                    Icons.hourglass_top_rounded,
                title:
                    'Invoice not ready',
                message:
                    'The final service invoice becomes available after completion.',
              ),
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

          final serviceFee =
              (data['serviceFee']
                      as num?)
                  ?.toInt() ??
              0;

          final travelFee =
              (data['dispatchFee']
                      as num?)
                  ?.toInt() ??
              (data['travelFee']
                      as num?)
                  ?.toInt() ??
              0;

          final extraFee =
              (data['extraFee']
                      as num?)
                  ?.toInt() ??
              0;

          final discount =
              approved > total
                  ? approved - total
                  : 0;

          final uid =
              FirebaseAuth.instance
                  .currentUser
                  ?.uid;

          final provider =
              uid ==
                  data['providerId'];

          final driver =
              uid ==
                  data['driverId'];

          final driverReported =
              data['driverReportedPayment'] ==
                  true;

          final providerConfirmed =
              data['providerConfirmedPayment'] ==
                  true;

          final paymentMethod =
              data['paymentMethod']
                  as String?;

          final providerName =
              data['providerName']
                      as String? ??
                  'Service Provider';

          final driverName =
              data['driverName']
                      as String? ??
                  'Driver';

          final registration =
              data['registration']
                      as String? ??
                  '';

          final vehicle = [
            data['vehicleType']
                    as String? ??
                '',
            data['modelYear']
                    as String? ??
                '',
            registration,
          ]
              .where(
                (value) =>
                    value.trim().isNotEmpty,
              )
              .join(' • ');

          final completedAt =
              (data['completedAt']
                      as Timestamp?)
                  ?.toDate()
                  .toLocal();

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
              _RaInvoiceHero(
                total:
                    money(total),
                requestId:
                    widget.requestId,
                completedAt:
                    completedAt,
                paymentConfirmed:
                    providerConfirmed,
              ),

              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title:
                    'Service details',
                subtitle:
                    'RoadAssist record for this completed roadside job.',
              ),

              const SizedBox(height: 10),

              _RaInvoiceSurface(
                child: Column(
                  children: [
                    _RaInvoiceInfoRow(
                      icon: Icons
                          .person_outline_rounded,
                      label:
                          'Driver',
                      value:
                          driverName,
                    ),

                    const _RaInvoiceDivider(),

                    _RaInvoiceInfoRow(
                      icon: Icons
                          .engineering_outlined,
                      label:
                          'Provider',
                      value:
                          providerName,
                    ),

                    const _RaInvoiceDivider(),

                    _RaInvoiceInfoRow(
                      icon: Icons
                          .car_repair_outlined,
                      label:
                          'Reported problem',
                      value:
                          requestIssueLabel(
                        data,
                      ),
                    ),

                    if (vehicle.isNotEmpty) ...[
                      const _RaInvoiceDivider(),
                      _RaInvoiceInfoRow(
                        icon: Icons
                            .directions_car_outlined,
                        label:
                            'Vehicle',
                        value:
                            vehicle,
                      ),
                    ],

                    if (data['providerDiagnosis']
                            is String &&
                        (data['providerDiagnosis']
                                as String)
                            .trim()
                            .isNotEmpty) ...[
                      const _RaInvoiceDivider(),
                      _RaInvoiceInfoRow(
                        icon: Icons
                            .fact_check_outlined,
                        label:
                            'Diagnosis / approved work',
                        value:
                            data['providerDiagnosis']
                                as String,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title:
                    'Price breakdown',
                subtitle:
                    'Final bill based on approved RoadAssist service charges.',
              ),

              const SizedBox(height: 10),

              _RaInvoiceSurface(
                child: Column(
                  children: [
                    _RaInvoicePriceRow(
                      label:
                          'Service / labour',
                      value:
                          money(serviceFee),
                    ),

                    _RaInvoicePriceRow(
                      label:
                          'Travel / dispatch',
                      value:
                          money(travelFee),
                    ),

                    _RaInvoicePriceRow(
                      label:
                          'Parts / other approved charges',
                      value:
                          money(extraFee),
                    ),

                    if (discount > 0)
                      _RaInvoicePriceRow(
                        label:
                            'Discount',
                        value:
                            '-${money(discount)}',
                        success:
                            true,
                      ),

                    const Divider(),

                    _RaInvoicePriceRow(
                      label:
                          'Final total',
                      value:
                          money(total),
                      strong:
                          true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title:
                    'Payment status',
                subtitle:
                    'RoadAssist records cash or external payment confirmation only.',
              ),

              const SizedBox(height: 10),

              _RaInvoicePaymentCard(
                driverReported:
                    driverReported,
                providerConfirmed:
                    providerConfirmed,
                paymentMethod:
                    paymentMethod,
              ),

              if (driver &&
                  !driverReported) ...[
                const SizedBox(height: 11),

                _RaInvoiceSurface(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Text(
                        'Record Payment',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Only record payment after money has actually been paid to the provider.',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 8.5,
                          height: 1.45,
                          color: Theme.of(
                            context,
                          )
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                record(
                                  'cash',
                                );
                              },
                        icon: const Icon(
                          Icons
                              .payments_outlined,
                        ),
                        label: const Text(
                          'I Paid Cash',
                        ),
                      ),

                      const SizedBox(height: 7),

                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                record(
                                  'external',
                                );
                              },
                        icon: const Icon(
                          Icons
                              .open_in_new_rounded,
                        ),
                        label: const Text(
                          'I Paid Outside the App',
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (provider &&
                  driverReported &&
                  !providerConfirmed) ...[
                const SizedBox(height: 11),

                SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed: saving ||
                            paymentMethod ==
                                null
                        ? null
                        : () {
                            record(
                              paymentMethod,
                            );
                          },
                    icon: const Icon(
                      Icons
                          .check_circle_outline_rounded,
                    ),
                    label: const Text(
                      'Confirm Payment Received',
                    ),
                  ),
                ),
              ],

              if (saving) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],

              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title:
                    'Warranty',
                subtitle:
                    'Any agreed service warranty is shown from the completed job record.',
              ),

              const SizedBox(height: 10),

              ServiceWarranty(
                requestId:
                    widget.requestId,
                job:
                    data,
              ),

              if (driver) ...[
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () {
                      push(
                        context,
                        DisputeScreen(
                          requestId:
                              widget.requestId,
                          sameProblem:
                              true,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons
                          .published_with_changes_outlined,
                    ),
                    label: const Text(
                      'Same Problem / Warranty Review',
                    ),
                  ),
                ),
              ],

              if (driver ||
                  provider) ...[
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () {
                      push(
                        context,
                        DisputeScreen(
                          requestId:
                              widget.requestId,
                        ),
                      );
                    },
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
                const SizedBox(height: 25),

                const _RaInvoiceSectionHeading(
                  title:
                      'Approval history',
                  subtitle:
                      'Original offers and later repair revisions recorded for this service.',
                ),

                const SizedBox(height: 10),

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

class _RaInvoiceHero extends StatelessWidget {
  const _RaInvoiceHero({
    required this.total,
    required this.requestId,
    required this.completedAt,
    required this.paymentConfirmed,
  });

  final String total;
  final String requestId;
  final DateTime? completedAt;
  final bool paymentConfirmed;

  String get dateLabel {
    final value =
        completedAt;

    if (value == null) {
      return 'Completion time unavailable';
    }

    final hour =
        value.hour % 12 == 0
            ? 12
            : value.hour % 12;

    final minute =
        value.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} • $hour:$minute $period';
  }

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
                    0xFF08635D,
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
          24,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .receipt_long_outlined,
                  color:
                      Colors.white,
                ),
              ),
              const Spacer(),
              StatusPill(
                label:
                    paymentConfirmed
                        ? 'PAID'
                        : 'COMPLETED',
                tone:
                    paymentConfirmed
                        ? RaTone
                            .success
                        : RaTone.info,
              ),
            ],
          ),

          const SizedBox(
            height: 17,
          ),

          Text(
            'FINAL TOTAL',
            style: GoogleFonts
                .plusJakartaSans(
              color: Colors.white
                  .withValues(
                alpha: .65,
              ),
              fontSize: 8,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: .8,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            total,
            style: GoogleFonts
                .plusJakartaSans(
              color: Colors.white,
              fontSize: 27,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            dateLabel,
            style: GoogleFonts
                .plusJakartaSans(
              color: Colors.white70,
              fontSize: 8.5,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            'JOB $requestId',
            maxLines: 1,
            overflow:
                TextOverflow
                    .ellipsis,
            style: GoogleFonts
                .plusJakartaSans(
              color: Colors.white
                  .withValues(
                alpha: .52,
              ),
              fontSize: 7.5,
              fontWeight:
                  FontWeight.w600,
              letterSpacing: .45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaInvoiceSectionHeading
    extends StatelessWidget {
  const _RaInvoiceSectionHeading({
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
          CrossAxisAlignment
              .start,
      children: [
        Text(
          title,
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 16.5,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          subtitle,
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 9,
            height: 1.4,
            color: colors
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaInvoiceSurface
    extends StatelessWidget {
  const _RaInvoiceSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
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
      child: child,
    );
  }
}

class _RaInvoiceInfoRow
    extends StatelessWidget {
  const _RaInvoiceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(
                alpha: .07,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
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
                  label,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    height: 1.4,
                    fontWeight:
                        FontWeight
                            .w600,
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

class _RaInvoiceDivider
    extends StatelessWidget {
  const _RaInvoiceDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 47,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(
        alpha: .35,
      ),
    );
  }
}

class _RaInvoicePriceRow
    extends StatelessWidget {
  const _RaInvoicePriceRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.success = false,
  });

  final String label;
  final String value;
  final bool strong;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize:
                    strong ? 10 : 9,
                fontWeight:
                    strong
                        ? FontWeight
                            .w700
                        : FontWeight
                            .w500,
                color: strong
                    ? colors.onSurface
                    : colors
                        .onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts
                .plusJakartaSans(
              fontSize:
                  strong ? 13 : 9.5,
              fontWeight:
                  strong
                      ? FontWeight
                          .w800
                      : FontWeight
                          .w600,
              color: success
                  ? raSuccess
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaInvoicePaymentCard
    extends StatelessWidget {
  const _RaInvoicePaymentCard({
    required this.driverReported,
    required this.providerConfirmed,
    required this.paymentMethod,
  });

  final bool driverReported;
  final bool providerConfirmed;
  final String? paymentMethod;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final Color tone;
    final IconData icon;
    final String title;
    final String message;

    if (providerConfirmed) {
      tone = raSuccess;
      icon =
          Icons.verified_outlined;
      title =
          'Payment confirmed';
      message =
          'The provider confirmed that payment was received.';
    } else if (driverReported) {
      tone = raGold;
      icon =
          Icons.hourglass_top_rounded;
      title =
          'Awaiting provider confirmation';
      message =
          'The driver reported payment${paymentMethod == null ? '' : ' by ${paymentMethod!.replaceAll('_', ' ')}'}.';
    } else {
      tone = colors.primary;
      icon =
          Icons.payments_outlined;
      title =
          'Payment not recorded';
      message =
          'No cash or external payment has been recorded for this job.';
    }

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: .07,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: tone.withValues(
            alpha: .18,
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
            color: tone,
            size: 21,
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
                    fontSize: 10.5,
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
                    fontSize: 8.6,
                    height: 1.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  'RoadAssist does not process an online payment for this record.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.8,
                    height: 1.4,
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

    revisions =
        ref.collection(
          'repairQuotes',
        ).snapshots();

    decisions =
        ref.collection(
          'repairDecisions',
        ).snapshots();

    initialQuote =
        widget.selectedQuoteId ==
                null
            ? null
            : ref
                .collection(
                  'quotes',
                )
                .doc(
                  widget
                      .selectedQuoteId,
                )
                .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return _RaInvoiceSurface(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          if (initialQuote != null)
            StreamBuilder<
                DocumentSnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
                  initialQuote,
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot
                    .hasError) {
                  return const InlineMessage(
                    icon: Icons
                        .error_outline_rounded,
                    text:
                        'Could not load the original approved quote.',
                  );
                }

                final quote =
                    snapshot.data
                        ?.data();

                if (quote ==
                    null) {
                  return const LinearProgressIndicator();
                }

                final quoteType =
                    quote['quoteType']
                            as String? ??
                        'service';

                return _RaInvoiceApprovalEntry(
                  icon: Icons
                      .request_quote_outlined,
                  title:
                      'Original approved ${quoteType == 'inspection' ? 'inspection' : 'service'} offer',
                  amount:
                      'Rs. ${quote['total'] ?? 0}',
                  message:
                      quote['notes']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? '${quote['notes']}'
                          : 'No additional quote notes recorded.',
                  tone:
                      Theme.of(
                    context,
                  ).colorScheme.primary,
                );
              },
            ),

          if (initialQuote !=
              null)
            const SizedBox(
              height: 10,
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
                stream:
                    revisions,
                builder: (
                  context,
                  revisionSnapshot,
                ) {
                  if (revisionSnapshot
                          .hasError ||
                      decisionSnapshot
                          .hasError) {
                    return const InlineMessage(
                      icon: Icons
                          .history_toggle_off_rounded,
                      text:
                          'Could not load quote approval history.',
                    );
                  }

                  if (!revisionSnapshot
                          .hasData ||
                      !decisionSnapshot
                          .hasData) {
                    return const LinearProgressIndicator();
                  }

                  final outcomes = {
                    for (final decision
                        in decisionSnapshot
                            .data!
                            .docs)
                      decision.id:
                          decision
                              .data(),
                  };

                  final entries =
                      revisionSnapshot
                          .data!
                          .docs
                          .toList();

                  entries.sort(
                    (a, b) {
                      final aTime =
                          (a.data()[
                                      'createdAt']
                                  as Timestamp?)
                              ?.toDate();

                      final bTime =
                          (b.data()[
                                      'createdAt']
                                  as Timestamp?)
                              ?.toDate();

                      if (aTime ==
                              null &&
                          bTime ==
                              null) {
                        return 0;
                      }

                      if (aTime ==
                          null) {
                        return 1;
                      }

                      if (bTime ==
                          null) {
                        return -1;
                      }

                      return aTime
                          .compareTo(
                        bTime,
                      );
                    },
                  );

                  if (entries
                      .isEmpty) {
                    return Text(
                      'No repair revisions were proposed.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.8,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (var index =
                              0;
                          index <
                              entries
                                  .length;
                          index++) ...[
                        if (index >
                            0)
                          const SizedBox(
                            height: 10,
                          ),

                        _RaInvoiceRevisionEntry(
                          revision:
                              entries[index]
                                  .data(),
                          decision:
                              outcomes[
                                entries[index]
                                    .id
                              ],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RaInvoiceApprovalEntry
    extends StatelessWidget {
  const _RaInvoiceApprovalEntry({
    required this.icon,
    required this.title,
    required this.amount,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String amount;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: .06,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color: tone.withValues(
            alpha: .14,
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
            color: tone,
            size: 20,
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
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  amount,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.2,
                    height: 1.4,
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

class _RaInvoiceRevisionEntry
    extends StatelessWidget {
  const _RaInvoiceRevisionEntry({
    required this.revision,
    required this.decision,
  });

  final Map<String, dynamic>
      revision;

  final Map<String, dynamic>?
      decision;

  @override
  Widget build(BuildContext context) {
    final outcome =
        decision?['decision']
                as String? ??
            'not approved';

    final color =
        switch (outcome) {
      'approved' =>
        raSuccess,
      'rejected' =>
        raDanger,
      _ =>
        raGold,
    };

    final icon =
        switch (outcome) {
      'approved' =>
        Icons.check_circle_outline_rounded,
      'rejected' =>
        Icons.cancel_outlined,
      _ =>
        Icons.schedule_outlined,
    };

    final timestamp =
        decision?['createdAt']
                as Timestamp? ??
            revision['createdAt']
                as Timestamp?;

    final value =
        timestamp
            ?.toDate()
            .toLocal();

    final dateLabel =
        value == null
            ? 'Decision time unavailable'
            : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

    final previous =
        revision['previousTotal'] ??
            0;

    final total =
        revision['total'] ??
            0;

    final work =
        revision['diagnosisAndWork']
                ?.toString()
                .trim() ??
            '';

    final reason =
        revision['changeReason']
                ?.toString()
                .trim() ??
            '';

    final photos =
        List<String>.from(
      revision['evidencePhotoData']
              as List? ??
          const [],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        _RaInvoiceApprovalEntry(
          icon: icon,
          title:
              outcome.replaceAll(
                '_',
                ' ',
              ).toUpperCase(),
          amount:
              'Rs. $previous → Rs. $total',
          message: [
            if (work.isNotEmpty)
              work,
            if (reason.isNotEmpty)
              'Reason: $reason',
            dateLabel,
          ].join('\n'),
          tone: color,
        ),

        if (photos.isNotEmpty) ...[
          const SizedBox(
            height: 7,
          ),
          RevisionEvidencePhotos(
            photos: photos,
          ),
        ],
      ],
    );
  }
}