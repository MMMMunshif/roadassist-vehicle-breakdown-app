part of '../../screens.dart';

class ProviderCompletedScreen extends StatelessWidget {
  const ProviderCompletedScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  final String requestId;
  final Map<String, dynamic> requestData;

  String _money(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();

    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 &&
          (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(digits[index]);
    }

    return 'Rs. ${negative ? '-' : ''}${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchRequest(
        requestId,
      ),
      builder: (
        context,
        snapshot,
      ) {
        final liveData =
            snapshot.data?.data();

        final data = liveData == null
            ? requestData
            : <String, dynamic>{
                ...requestData,
                ...liveData,
              };

        return _ProviderCompletedContent(
          requestId: requestId,
          data: data,
          money: _money,
        );
      },
    );
  }
}

class _ProviderCompletedContent
    extends StatelessWidget {
  const _ProviderCompletedContent({
    required this.requestId,
    required this.data,
    required this.money,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final String Function(int) money;

  String _dateTimeLabel(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return 'Completion time unavailable';
    }

    final value =
        timestamp.toDate().toLocal();

    final day =
        value.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        value.month.toString().padLeft(
              2,
              '0',
            );

    final hour =
        value.hour % 12 == 0
            ? 12
            : value.hour % 12;

    final minute =
        value.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '$day/$month/${value.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final driverName =
        data['driverName'] as String? ??
            'Driver';

    final driverPhone =
        data['driverPhone'] as String? ??
            '';

    final providerName =
        data['providerName'] as String? ??
            'Service Provider';

    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ]
        .where(
          (value) =>
              value.trim().isNotEmpty,
        )
        .join(' • ');

    final location =
        data['locationLabel'] as String? ??
            data['location'] as String? ??
            'Location unavailable';

    final landmark =
        data['landmark'] as String? ??
            '';

    final serviceNotes =
        data['serviceNotes'] as String? ??
            '';

    final providerDiagnosis =
        data['providerDiagnosis']
                as String? ??
            '';

    final finalTotal =
        (data['finalCost'] as num?)
                ?.toInt() ??
            (data['estimatedCost'] as num?)
                ?.toInt() ??
            0;

    final driverReportedPayment =
        data['driverReportedPayment'] ==
            true;

    final providerConfirmedPayment =
        data['providerConfirmedPayment'] ==
            true;

    final paymentMethod =
        data['paymentMethod'] as String?;

    final completionState =
        data['completionState'] as String? ??
            '';

    final completed =
        data['status'] == 'completed';

    final completedAt =
        data['completedAt'] as Timestamp?;

    final warrantyDays =
        (data['warrantyDays'] as num?)
                ?.toInt() ??
            0;

    final servicePhotos =
        (data['servicePhotoData']
                    as List<dynamic>? ??
                const [])
            .whereType<String>()
            .toList();

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          completed
              ? 'Job Completed'
              : 'Completion Submitted',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Invoice',
            onPressed: completed
                ? () {
                    push(
                      context,
                      InvoiceScreen(
                        requestId:
                            requestId,
                      ),
                    );
                  }
                : null,
            icon: const Icon(
              Icons
                  .receipt_long_outlined,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
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
            _ProviderCompletedHero(
              completed:
                  completed,
              requestId:
                  requestId,
              completedLabel:
                  _dateTimeLabel(
                completedAt,
              ),
              paymentConfirmed:
                  providerConfirmedPayment,
              completionState:
                  completionState,
            ),

            const SizedBox(height: 24),

            const _ProviderCompletedSectionHeading(
              title: 'Service summary',
              subtitle:
                  'Final RoadAssist information recorded for this roadside assistance job.',
            ),

            const SizedBox(height: 10),

            _ProviderCompletedSurface(
              child: Column(
                children: [
                  _ProviderCompletedRow(
                    icon: Icons
                        .car_repair_outlined,
                    label: 'Service',
                    value:
                        requestIssueLabel(
                      data,
                    ),
                  ),

                  const _ProviderCompletedDivider(),

                  _ProviderCompletedRow(
                    icon: Icons
                        .person_outline_rounded,
                    label: 'Driver',
                    value:
                        driverName,
                  ),

                  const _ProviderCompletedDivider(),

                  _ProviderCompletedRow(
                    icon: Icons
                        .engineering_outlined,
                    label: 'Provider',
                    value:
                        providerName,
                  ),

                  if (vehicle.isNotEmpty) ...[
                    const _ProviderCompletedDivider(),

                    _ProviderCompletedRow(
                      icon: Icons
                          .directions_car_outlined,
                      label: 'Vehicle',
                      value:
                          vehicle,
                    ),
                  ],

                  const _ProviderCompletedDivider(),

                  _ProviderCompletedRow(
                    icon: Icons
                        .location_on_outlined,
                    label: 'Location',
                    value:
                        location,
                  ),

                  if (landmark
                      .trim()
                      .isNotEmpty) ...[
                    const _ProviderCompletedDivider(),

                    _ProviderCompletedRow(
                      icon:
                          Icons.signpost_outlined,
                      label: 'Landmark',
                      value:
                          landmark,
                    ),
                  ],
                ],
              ),
            ),

            if (providerDiagnosis
                    .trim()
                    .isNotEmpty ||
                serviceNotes
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 24),

              const _ProviderCompletedSectionHeading(
                title: 'Work performed',
                subtitle:
                    'Provider notes and diagnosis recorded during the service.',
              ),

              const SizedBox(height: 10),

              _ProviderCompletedSurface(
                child: Column(
                  children: [
                    if (providerDiagnosis
                        .trim()
                        .isNotEmpty)
                      _ProviderCompletedRow(
                        icon: Icons
                            .fact_check_outlined,
                        label:
                            'Diagnosis / approved work',
                        value:
                            providerDiagnosis,
                      ),

                    if (providerDiagnosis
                            .trim()
                            .isNotEmpty &&
                        serviceNotes
                            .trim()
                            .isNotEmpty)
                      const _ProviderCompletedDivider(),

                    if (serviceNotes
                        .trim()
                        .isNotEmpty)
                      _ProviderCompletedRow(
                        icon:
                            Icons.notes_outlined,
                        label:
                            'Service notes',
                        value:
                            serviceNotes,
                      ),
                  ],
                ),
              ),
            ],

            if (servicePhotos.isNotEmpty) ...[
              const SizedBox(height: 24),

              const _ProviderCompletedSectionHeading(
                title:
                    'Service evidence',
                subtitle:
                    'Photos attached by the provider while documenting the completed work.',
              ),

              const SizedBox(height: 10),

              _ProviderCompletedPhotoGallery(
                photos:
                    servicePhotos,
              ),
            ],

            const SizedBox(height: 24),

            const _ProviderCompletedSectionHeading(
              title: 'Final amount',
              subtitle:
                  'The final RoadAssist charge recorded for this completed service.',
            ),

            const SizedBox(height: 10),

            _ProviderCompletedTotal(
              total: finalTotal > 0
                  ? money(
                      finalTotal,
                    )
                  : 'Not recorded',
            ),

            const SizedBox(height: 24),

            const _ProviderCompletedSectionHeading(
              title: 'Payment',
              subtitle:
                  'RoadAssist records cash or external payment confirmation for this job.',
            ),

            const SizedBox(height: 10),

            _ProviderCompletedPayment(
              driverReported:
                  driverReportedPayment,
              confirmed:
                  providerConfirmedPayment,
              method:
                  paymentMethod,
            ),

            if (warrantyDays > 0) ...[
              const SizedBox(height: 24),

              const _ProviderCompletedSectionHeading(
                title: 'Warranty',
                subtitle:
                    'Any agreed service warranty remains linked to the completed request.',
              ),

              const SizedBox(height: 10),

              ServiceWarranty(
                requestId:
                    requestId,
                job:
                    data,
              ),
            ],

            const SizedBox(height: 25),

            _ProviderCompletedContactCard(
              driverName:
                  driverName,
              driverPhone:
                  driverPhone,
              requestId:
                  requestId,
            ),

            const SizedBox(height: 13),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: completed
                    ? () {
                        push(
                          context,
                          InvoiceScreen(
                            requestId:
                                requestId,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(
                  Icons
                      .receipt_long_outlined,
                ),
                label: const Text(
                  'View Full Invoice',
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  push(
                    context,
                    ProviderRequestDetailsScreen(
                      requestId:
                          requestId,
                      data:
                          data,
                    ),
                  );
                },
                icon: const Icon(
                  Icons
                      .description_outlined,
                ),
                label: const Text(
                  'View Job Details',
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  replace(
                    context,
                    const ProviderShell(),
                  );
                },
                icon: const Icon(
                  Icons
                      .dashboard_outlined,
                ),
                label: const Text(
                  'Back to Dashboard',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCompletedHero
    extends StatelessWidget {
  const _ProviderCompletedHero({
    required this.completed,
    required this.requestId,
    required this.completedLabel,
    required this.paymentConfirmed,
    required this.completionState,
  });

  final bool completed;

  final String requestId;
  final String completedLabel;

  final bool paymentConfirmed;

  final String completionState;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final title = completed
        ? 'Assistance completed'
        : 'Completion submitted';

    final description = completed
        ? 'The roadside service has been completed and recorded in your provider history.'
        : completionState == 'pending'
            ? 'The work has been submitted. The driver still needs to review and confirm completion.'
            : 'The completion workflow is still being processed.';

    return Container(
      padding:
          const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B477D),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
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
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  completed
                      ? Icons
                          .task_alt_rounded
                      : Icons
                          .hourglass_top_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const Spacer(),

              StatusPill(
                label: paymentConfirmed
                    ? 'PAID'
                    : completed
                        ? 'COMPLETED'
                        : 'PENDING',
                tone: paymentConfirmed ||
                        completed
                    ? RaTone.success
                    : RaTone.warning,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(
                alpha: .76,
              ),
              fontSize: 9.3,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 14),

          if (completed)
            Row(
              children: [
                const Icon(
                  Icons
                      .calendar_today_outlined,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    completedLabel,
                    style:
                        GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 8.3,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 5),

          Text(
            'JOB $requestId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(
                alpha: .50,
              ),
              fontSize: 7.4,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCompletedSectionHeading
    extends StatelessWidget {
  const _ProviderCompletedSectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProviderCompletedSurface
    extends StatelessWidget {
  const _ProviderCompletedSurface({
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
          const EdgeInsets.all(14),
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
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _ProviderCompletedRow
    extends StatelessWidget {
  const _ProviderCompletedRow({
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
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
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
              size: 18,
              color: colors.primary,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 7.8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 9.8,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w700,
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

class _ProviderCompletedDivider
    extends StatelessWidget {
  const _ProviderCompletedDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 48,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(
        alpha: .35,
      ),
    );
  }
}

class _ProviderCompletedTotal
    extends StatelessWidget {
  const _ProviderCompletedTotal({
    required this.total,
  });

  final String total;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: .14,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'FINAL SERVICE TOTAL',
                  style:
                      GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 7.5,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: .55,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  total,
                  style:
                      GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
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

class _ProviderCompletedPayment
    extends StatelessWidget {
  const _ProviderCompletedPayment({
    required this.driverReported,
    required this.confirmed,
    required this.method,
  });

  final bool driverReported;
  final bool confirmed;
  final String? method;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    late final Color tone;
    late final IconData icon;
    late final String title;
    late final String message;

    if (confirmed) {
      tone = raSuccess;

      icon =
          Icons.verified_outlined;

      title =
          'Payment confirmed';

      message =
          'The provider payment receipt has been confirmed for this completed job.';
    } else if (driverReported) {
      tone = raGold;

      icon =
          Icons.hourglass_top_rounded;

      title =
          'Driver reported payment';

      message =
          'Payment${method == null ? '' : ' by ${method!.replaceAll('_', ' ')}'} was reported and is waiting for provider confirmation.';
    } else {
      tone = colors.primary;

      icon =
          Icons.payments_outlined;

      title =
          'Payment not recorded';

      message =
          'No cash or external payment has been recorded for this job yet.';
    }

    return Container(
      padding:
          const EdgeInsets.all(14),
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
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: tone,
            size: 21,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 10.3,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  message,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    height: 1.45,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'RoadAssist records payment confirmation but does not process an in-app payment for this service.',
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 7.7,
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

class _ProviderCompletedPhotoGallery
    extends StatelessWidget {
  const _ProviderCompletedPhotoGallery({
    required this.photos,
  });

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder:
            (context, index) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder: (
          context,
          index,
        ) {
          try {
            final source =
                photos[index];

            final clean =
                source.contains(',')
                    ? source
                        .split(',')
                        .last
                    : source;

            return ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              child: Image.memory(
                base64Decode(clean),
                width: 116,
                height: 116,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _ProviderCompletedBrokenPhoto(
                    colors: colors,
                  );
                },
              ),
            );
          } catch (_) {
            return _ProviderCompletedBrokenPhoto(
              colors: colors,
            );
          }
        },
      ),
    );
  }
}

class _ProviderCompletedBrokenPhoto
    extends StatelessWidget {
  const _ProviderCompletedBrokenPhoto({
    required this.colors,
  });

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      alignment:
          Alignment.center,
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        color: colors
            .onSurfaceVariant,
      ),
    );
  }
}

class _ProviderCompletedContactCard
    extends StatelessWidget {
  const _ProviderCompletedContactCard({
    required this.driverName,
    required this.driverPhone,
    required this.requestId,
  });

  final String driverName;
  final String driverPhone;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(14),
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
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
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
                radius:
                    22,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style:
                          GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Service customer',
                      style:
                          GoogleFonts.plusJakartaSans(
                        fontSize: 8.2,
                        color: colors
                            .onSurfaceVariant,
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
                  onPressed:
                      driverPhone
                              .trim()
                              .isEmpty
                          ? null
                          : () {
                              showCallPrompt(
                                context,
                                name:
                                    driverName,
                                number:
                                    driverPhone,
                              );
                            },
                  icon: const Icon(
                    Icons.call_outlined,
                  ),
                  label:
                      const Text('Call'),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    push(
                      context,
                      ChatScreen(
                        requestId:
                            requestId,
                        peerName:
                            driverName,
                        peerPhone:
                            driverPhone,
                      ),
                    );
                  },
                  icon: _UnreadChatIcon(
                    requestId:
                        requestId,
                    seenField:
                        'providerMessagesSeenAt',
                  ),
                  label: const Text(
                    'Message',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}