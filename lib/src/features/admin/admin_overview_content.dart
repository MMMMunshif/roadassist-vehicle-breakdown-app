part of '../../screens.dart';

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                const Color(0xFF007D70),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                height: RaSpace.lg,
              ),
              Text(
                'Operations overview',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Live operational indicators from the currently loaded records.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: Colors.white.withValues(
                    alpha: .84,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: RaSpace.lg,
        ),

        Container(
          padding: const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration: BoxDecoration(
            color: colors
                .surfaceContainerHighest
                .withValues(alpha: .42),
            borderRadius:
                BorderRadius.circular(15),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: colors.primary,
              ),
              const SizedBox(
                width: RaSpace.sm,
              ),
              Expanded(
                child: Text(
                  'Each overview card is capped at 100 loaded records. These figures are operational indicators, not lifetime totals. Complaint decisions do not automatically alter job status or money.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: RaSpace.xl,
        ),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final width =
                constraints.maxWidth;

            final cardWidth =
                width >= 1050
                ? (width - 36) / 4
                : width >= 600
                ? (width - 12) / 2
                : width;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection: 'users',
                  title: 'Users loaded',
                  subtitle:
                      'User profiles in current scope',
                  icon:
                      Icons.people_outline_rounded,
                  counter: (records) =>
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
                  icon: Icons
                      .handyman_outlined,
                  counter: (records) =>
                      records
                          .where(
                            (record) =>
                                record.data()[
                                        'online'] ==
                                    true &&
                                _providerHasCurrentVerification(
                                  record
                                      .data(),
                                ),
                          )
                          .length,
                ),
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection:
                      'requests',
                  title: 'Active jobs',
                  subtitle:
                      'Accepted, travelling or arrived',
                  icon:
                      Icons.route_outlined,
                  counter: (records) =>
                      records
                          .where(
                            (record) =>
                                const [
                                  'accepted',
                                  'en_route',
                                  'arrived',
                                ].contains(
                                  record.data()[
                                      'status'],
                                ),
                          )
                          .length,
                ),
                _AdminOverviewMetricCard(
                  width: cardWidth,
                  collection:
                      'accountModeration',
                  title:
                      'Flagged accounts',
                  subtitle:
                      'Accounts requiring review',
                  icon: Icons
                      .flag_outlined,
                  danger: true,
                  counter: (records) =>
                      records
                          .where(
                            (record) =>
                                record.data()[
                                        'flagged'] ==
                                    true,
                          )
                          .length,
                ),
              ],
            );
          },
        ),
      ],
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
        Map<String, dynamic>
      >
    >,
  )
  counter;

  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final tone =
        danger ? colors.error : colors.primary;

    return SizedBox(
      width: width,
      child: StreamBuilder<
        QuerySnapshot<
          Map<String, dynamic>
        >
      >(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .limit(100)
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          final value = snapshot.hasData
              ? counter(snapshot.data!.docs)
              : null;

          return Container(
            constraints:
                const BoxConstraints(
              minHeight: 158,
            ),
            padding: const EdgeInsets.all(
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
                        color: tone.withValues(
                          alpha: .1,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: tone,
                      ),
                    ),
                    const Spacer(),
                    if (!snapshot.hasData &&
                        !snapshot.hasError)
                      const SizedBox(
                        width: 20,
                        height: 20,
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
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  snapshot.hasError
                      ? '—'
                      : '${value ?? '…'}',
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    color: snapshot.hasError
                        ? colors
                            .onSurfaceVariant
                        : tone,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme
                      .textTheme.titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snapshot.hasError
                      ? 'Unable to load. Check admin access.'
                      : subtitle,
                  style:
                      theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}