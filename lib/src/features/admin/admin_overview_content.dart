part of '../../screens.dart';

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return ListView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        32,
      ),
      children: [
        _RaAdminOverviewHero(
          dark:
              theme.brightness ==
                  Brightness.dark,
        ),

        const SizedBox(height: 14),

        const _RaAdminOverviewNotice(
          icon:
              Icons.info_outline_rounded,
          title:
              'Loaded operational indicators',
          message:
              'Each overview metric reads up to 100 current records. These figures are operational indicators, not lifetime totals. Complaint decisions do not automatically change job status or payment records.',
          tone: raBlue,
        ),

        const SizedBox(height: 23),

        const _RaAdminOverviewHeading(
          title: 'Live platform snapshot',
          subtitle:
              'Current RoadAssist account, provider and assistance activity.',
        ),

        const SizedBox(height: 11),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final width =
                constraints.maxWidth;

            final columns =
                width >= 900
                    ? 4
                    : width >= 520
                        ? 2
                        : 1;

            const spacing =
                10.0;

            final cardWidth =
                columns == 1
                    ? width
                    : (width -
                            spacing *
                                (columns -
                                    1)) /
                        columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection: 'users',
                  title: 'Users loaded',
                  subtitle:
                      'User profiles in current scope',
                  icon: Icons
                      .people_outline_rounded,
                  counter: (
                    records,
                  ) =>
                      records.length,
                ),
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection:
                      'providerDirectory',
                  title:
                      'Online verified providers',
                  subtitle:
                      'Available providers in loaded records',
                  icon:
                      Icons.handyman_outlined,
                  counter: (
                    records,
                  ) =>
                      records.where(
                    (
                      record,
                    ) {
                      final data =
                          record.data();

                      return data['online'] ==
                              true &&
                          _providerHasCurrentVerification(
                            data,
                          );
                    },
                  ).length,
                ),
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection: 'requests',
                  title: 'Active jobs',
                  subtitle:
                      'Accepted, travelling or arrived',
                  icon:
                      Icons.route_outlined,
                  counter: (
                    records,
                  ) =>
                      records.where(
                    (
                      record,
                    ) {
                      return const [
                        'accepted',
                        'en_route',
                        'arrived',
                      ].contains(
                        record.data()[
                            'status'],
                      );
                    },
                  ).length,
                ),
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection:
                      'accountModeration',
                  title:
                      'Flagged accounts',
                  subtitle:
                      'Accounts requiring review',
                  icon:
                      Icons.flag_outlined,
                  danger: true,
                  counter: (
                    records,
                  ) =>
                      records.where(
                    (
                      record,
                    ) =>
                        record.data()[
                                'flagged'] ==
                            true,
                  ).length,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 25),

        const _RaAdminOverviewHeading(
          title: 'Operational activity',
          subtitle:
              'Live indicators from the latest loaded assistance records.',
        ),

        const SizedBox(height: 11),

        const _RaAdminOverviewRequestSummary(),

        const SizedBox(height: 14),

        const _RaAdminOverviewNotice(
          icon:
              Icons.shield_outlined,
          title:
              'Administrative boundaries',
          message:
              'Overview information is for monitoring and triage. Use the dedicated Jobs, Complaints, Users and Providers workspaces before taking administrative action.',
          tone: raGold,
        ),
      ],
    );
  }
}

class _RaAdminOverviewHero
    extends StatelessWidget {
  const _RaAdminOverviewHero({
    required this.dark,
  });

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF075A68),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
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
                child: const Icon(
                  Icons
                      .monitor_heart_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),

              const Spacer(),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),
                child: Text(
                  'LIVE FIRESTORE',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Text(
            'Operations overview',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'A concise view of current RoadAssist users, verified providers and roadside assistance activity.',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(
                alpha: .76,
              ),
              fontSize: 9,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewMetricCard
    extends StatelessWidget {
  const _AdminOverviewMetricCard({
    required this.width,
    required this.collection,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.counter,
    this.danger = false,
  });

  final double width;
  final String collection;
  final String title;
  final String subtitle;
  final IconData icon;

  final int Function(
    List<
        QueryDocumentSnapshot<
            Map<String, dynamic>>>,
  ) counter;

  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final tone = danger
        ? colors.error
        : colors.primary;

    return SizedBox(
      width: width,
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .limit(100)
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          final value =
              snapshot.hasData
                  ? counter(
                      snapshot.data!.docs,
                    )
                  : null;

          return Container(
            constraints:
                const BoxConstraints(
              minHeight: 132,
            ),
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.brightness ==
                      Brightness.dark
                  ? const Color(
                      0xFF0D1D2B,
                    )
                  : colors.surface,
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: snapshot.hasError
                    ? colors.error
                        .withValues(
                        alpha: .20,
                      )
                    : colors.outlineVariant
                        .withValues(
                        alpha: .45,
                      ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration:
                          BoxDecoration(
                        color: tone
                            .withValues(
                          alpha: .08,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          13,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: tone,
                        size: 20,
                      ),
                    ),

                    const Spacer(),

                    if (!snapshot.hasData &&
                        !snapshot.hasError)
                      const SizedBox.square(
                        dimension: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),

                    if (snapshot.hasError)
                      Icon(
                        Icons
                            .cloud_off_outlined,
                        color: colors.error,
                        size: 19,
                      ),
                  ],
                ),

                const SizedBox(height: 15),

                Text(
                  snapshot.hasError
                      ? '—'
                      : '${value ?? '…'}',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                    color: snapshot.hasError
                        ? colors
                            .onSurfaceVariant
                        : tone,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  snapshot.hasError
                      ? 'Unable to load. Check admin access.'
                      : subtitle,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.6,
                    height: 1.35,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RaAdminOverviewRequestSummary
    extends StatelessWidget {
  const _RaAdminOverviewRequestSummary();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .orderBy(
            'createdAt',
            descending: true,
          )
          .limit(100)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const _RaAdminOverviewNotice(
            icon:
                Icons.cloud_off_outlined,
            title:
                'Request activity unavailable',
            message:
                'Unable to read recent request activity with the current admin access.',
            tone: raDanger,
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final docs =
            snapshot.data!.docs;

        int count(
          String status,
        ) {
          return docs.where(
            (
              document,
            ) {
              return document.data()[
                      'status'] ==
                  status;
            },
          ).length;
        }

        final searching =
            count('searching');

        final active =
            docs.where(
          (
            document,
          ) {
            return const [
              'accepted',
              'en_route',
              'arrived',
            ].contains(
              document.data()[
                  'status'],
            );
          },
        ).length;

        final completed =
            count('completed');

        final cancelled =
            count('cancelled');

        final paymentPending =
            docs.where(
          (
            document,
          ) {
            final data =
                document.data();

            return data['status'] ==
                    'completed' &&
                data[
                        'providerConfirmedPayment'] !=
                    true;
          },
        ).length;

        return _RaAdminOverviewSurface(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons
                        .analytics_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${docs.length} recent requests loaded',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final columns =
                      constraints.maxWidth >=
                              600
                          ? 5
                          : 2;

                  const gap =
                      8.0;

                  final width =
                      columns == 5
                          ? (constraints
                                      .maxWidth -
                                  gap * 4) /
                              5
                          : (constraints
                                      .maxWidth -
                                  gap) /
                              2;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      _RaAdminOverviewMiniMetric(
                        width: width,
                        label: 'Searching',
                        value:
                            searching,
                        tone: raGold,
                      ),
                      _RaAdminOverviewMiniMetric(
                        width: width,
                        label: 'Active',
                        value: active,
                        tone: Theme.of(
                          context,
                        )
                            .colorScheme
                            .primary,
                      ),
                      _RaAdminOverviewMiniMetric(
                        width: width,
                        label: 'Completed',
                        value:
                            completed,
                        tone:
                            raSuccess,
                      ),
                      _RaAdminOverviewMiniMetric(
                        width: width,
                        label: 'Cancelled',
                        value:
                            cancelled,
                        tone:
                            raDanger,
                      ),
                      _RaAdminOverviewMiniMetric(
                        width: width,
                        label:
                            'Payment pending',
                        value:
                            paymentPending,
                        tone:
                            raGold,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RaAdminOverviewMiniMetric
    extends StatelessWidget {
  const _RaAdminOverviewMiniMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.tone,
  });

  final double width;
  final String label;
  final int value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding:
            const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: tone.withValues(
            alpha: .06,
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 15,
                fontWeight:
                    FontWeight.w800,
                color: tone,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 7.2,
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaAdminOverviewSurface
    extends StatelessWidget {
  const _RaAdminOverviewSurface({
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
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : theme
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(18),
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

class _RaAdminOverviewHeading
    extends StatelessWidget {
  const _RaAdminOverviewHeading({
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
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaAdminOverviewNotice
    extends StatelessWidget {
  const _RaAdminOverviewNotice({
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
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              tone.withValues(alpha: .17),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.3,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.1,
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