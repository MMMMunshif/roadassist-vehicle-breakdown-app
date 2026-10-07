part of '../../screens.dart';

class _AdminUserActivity extends StatelessWidget {
  const _AdminUserActivity({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Text(
          'Account activity',
          style: theme.textTheme.titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: RaSpace.sm),

        Text(
          'Review recent jobs, cancellations and administrative actions associated with this account.',
          style: theme.textTheme.bodySmall
              ?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: RaSpace.md),

        for (final field in [
          'driverId',
          'providerId',
        ])
          Padding(
            padding: const EdgeInsets.only(
              bottom: RaSpace.sm,
            ),
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where(
                    field,
                    isEqualTo: uid,
                  )
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                final label =
                    field == 'driverId'
                    ? 'Driver jobs'
                    : 'Provider jobs';

                if (snapshot.hasError) {
                  return _AdminActivitySection(
                    icon: Icons
                        .route_outlined,
                    title: label,
                    subtitle:
                        'Could not load related jobs.',
                    children: const [],
                  );
                }

                if (!snapshot.hasData) {
                  return _AdminActivitySection(
                    icon: Icons
                        .route_outlined,
                    title: label,
                    subtitle:
                        'Loading job history…',
                    loading: true,
                    children: const [],
                  );
                }

                final docs =
                    snapshot.data!.docs;

                return _AdminActivitySection(
                  icon:
                      field == 'driverId'
                      ? Icons
                          .directions_car_outlined
                      : Icons
                          .home_repair_service_outlined,
                  title:
                      '$label (${docs.length})',
                  subtitle:
                      'Up to 50 records shown',
                  children: [
                    if (docs.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.all(
                          RaSpace.md,
                        ),
                        child: Text(
                          'No related jobs found.',
                        ),
                      ),
                    for (final doc in docs)
                      _AdminActivityJobTile(
                        requestId: doc.id,
                        data: doc.data(),
                      ),
                  ],
                );
              },
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(
            bottom: RaSpace.sm,
          ),
          child: StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where(
                  'cancelledBy',
                  isEqualTo: uid,
                )
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              final docs =
                  snapshot.data?.docs ??
                      <QueryDocumentSnapshot<
                          Map<String, dynamic>>>[];

              return _AdminActivitySection(
                icon: Icons.cancel_outlined,
                title:
                    'Cancellations (${docs.length})',
                subtitle:
                    'Requests cancelled by this account',
                loading:
                    !snapshot.hasData &&
                    !snapshot.hasError,
                children: [
                  if (snapshot.hasError)
                    const Padding(
                      padding:
                          EdgeInsets.all(
                        RaSpace.md,
                      ),
                      child: Text(
                        'Could not load cancellation history.',
                      ),
                    ),
                  if (snapshot.hasData &&
                      docs.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.all(
                        RaSpace.md,
                      ),
                      child: Text(
                        'No cancellations recorded.',
                      ),
                    ),
                  for (final doc in docs)
                    ListTile(
                      leading: const Icon(
                        Icons
                            .cancel_schedule_send_outlined,
                      ),
                      title: Text(
                        '${doc.data()['cancellationType'] ?? 'Cancellation'}',
                      ),
                      subtitle: Text(
                        '${doc.data()['cancellationReason'] ?? 'No reason recorded'}\nRequest: ${doc.id}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              );
            },
          ),
        ),

        StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('adminAudit')
              .where(
                'target',
                isEqualTo: uid,
              )
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            final docs =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

            return _AdminActivitySection(
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
                  const Padding(
                    padding:
                        EdgeInsets.all(
                      RaSpace.md,
                    ),
                    child: Text(
                      'Could not load audit history.',
                    ),
                  ),
                if (snapshot.hasData &&
                    docs.isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.all(
                      RaSpace.md,
                    ),
                    child: Text(
                      'No audit entries recorded.',
                    ),
                  ),
                for (final doc in docs)
                  ListTile(
                    leading: const Icon(
                      Icons
                          .admin_panel_settings_outlined,
                    ),
                    title: Text(
                      '${doc.data()['kind'] ?? 'Admin action'}',
                    ),
                    subtitle: Text(
                      '${doc.data()['reason'] ?? 'No reason recorded'}\nActor: ${doc.data()['actor'] ?? 'Unknown'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                    onTap: () => push(
                      context,
                      _AdminAuditScreen(
                        data: doc.data(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminActivitySection
    extends StatelessWidget {
  const _AdminActivitySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
                colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall
              ?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.all(
                RaSpace.lg,
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

class _AdminActivityJobTile
    extends StatelessWidget {
  const _AdminActivityJobTile({
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status =
        data['status']?.toString() ??
            'unknown';

    final paymentConfirmed =
        data['providerConfirmedPayment'] ==
            true;

    final arrivalConfirmed =
        data['arrivalConfirmedBy'] != null;

    return ListTile(
      leading: const Icon(
        Icons.route_outlined,
      ),
      title: Text(
        '${data['service'] ?? requestId}',
      ),
      subtitle: Text(
        '$status • Payment ${paymentConfirmed ? 'confirmed' : 'unconfirmed'}'
        '${arrivalConfirmed ? '\nArrival: ${data['arrivalConfirmationMethod']} at ${data['arrivalConfirmedAt']} - ${data['arrivalConfirmationReason']}' : ''}',
      ),
      isThreeLine:
          arrivalConfirmed,
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _AdminComplaintScreen(
            requestId: requestId,
          ),
        ),
      ),
    );
  }
}