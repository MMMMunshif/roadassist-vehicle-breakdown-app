part of '../../screens.dart';

class _AdminUserRow extends StatefulWidget {
  const _AdminUserRow({
    super.key,
    required this.uid,
    required this.data,
    required this.pendingOnly,
  });

  final String uid;
  final Map<String, dynamic> data;
  final bool pendingOnly;

  @override
  State<_AdminUserRow> createState() =>
      _AdminUserRowState();
}

class _AdminUserRowState
    extends State<_AdminUserRow> {
  late final review = FirebaseFirestore.instance
      .collection('accountModeration')
      .doc(widget.uid)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: review,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration: BoxDecoration(
              color: colors.errorContainer
                  .withValues(alpha: .30),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Text(
              'Could not load account review.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              vertical: RaSpace.sm,
            ),
            child:
                LinearProgressIndicator(),
          );
        }

        final moderation =
            snapshot.data!.data() ?? {};

        final validUntil =
            (moderation['validUntil']
                    as Timestamp?)
                ?.toDate();

        final verification =
            moderation['verification']
                    ?.toString() ??
                'pending';

        final status =
            verification == 'verified' &&
                    !(validUntil?.isAfter(
                          DateTime.now(),
                        ) ??
                        false)
                ? 'pending renewal'
                : verification;

        if (widget.pendingOnly &&
            !status.startsWith('pending')) {
          return const SizedBox.shrink();
        }

        final name =
            widget.data['displayName']
                    as String? ??
                widget.uid;

        final email =
            widget.data['email']
                    ?.toString() ??
                '';

        final role =
            widget.data['role']
                    ?.toString() ??
                'user';

        final accessStatus =
            moderation['status']
                    ?.toString() ??
                'active';

        final flagged =
            moderation['flagged'] == true;

        return Material(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => push(
              context,
              _AdminAccountScreen(
                uid: widget.uid,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(
                RaSpace.md,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border: Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(alpha: .55),
                ),
              ),
              child: Row(
                children: [
                  ProfileInitials(
                    name: name,
                    radius: 24,
                  ),

                  const SizedBox(
                    width: RaSpace.md,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          name,
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

                        if (email
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            email,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],

                        const SizedBox(
                          height: RaSpace.sm,
                        ),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _AdminStatusBadge(
                              status: role,
                            ),
                            _AdminStatusBadge(
                              status: status,
                            ),
                            if (accessStatus !=
                                'active')
                              _AdminStatusBadge(
                                status:
                                    accessStatus,
                              ),
                            if (flagged)
                              const _AdminStatusBadge(
                                status:
                                    'flagged',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: RaSpace.sm,
                  ),

                  Icon(
                    Icons
                        .chevron_right_rounded,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}