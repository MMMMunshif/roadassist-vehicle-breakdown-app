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
  late final Stream<
      DocumentSnapshot<Map<String, dynamic>>> review =
      FirebaseFirestore.instance
          .collection('accountModeration')
          .doc(widget.uid)
          .snapshots();

  String _friendly(
    String value,
  ) {
    final cleaned =
        value.replaceAll('_', ' ').trim();

    if (cleaned.isEmpty) {
      return 'Unknown';
    }

    return cleaned
        .split(' ')
        .where(
          (part) => part.isNotEmpty,
        )
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: review,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return Container(
            padding:
                const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.error
                  .withValues(alpha: .06),
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color: colors.error
                    .withValues(alpha: .18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons
                      .cloud_off_outlined,
                  size: 19,
                  color: colors.error,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Could not load account review.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 8.6,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            padding:
                const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: .22),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child:
                const LinearProgressIndicator(),
          );
        }

        final moderation =
            snapshot.data!.data() ??
                <String, dynamic>{};

        final validUntil =
            (moderation['validUntil']
                    as Timestamp?)
                ?.toDate();

        final verification =
            moderation['verification']
                    ?.toString() ??
                'pending';

        final verificationStatus =
            verification == 'verified' &&
                    !(validUntil?.isAfter(
                          DateTime.now(),
                        ) ??
                        false)
                ? 'pending renewal'
                : verification;

        if (widget.pendingOnly &&
            !verificationStatus
                .startsWith('pending')) {
          return const SizedBox.shrink();
        }

        final name =
            widget.data['displayName']
                    ?.toString()
                    .trim() ??
                '';

        final resolvedName =
            name.isEmpty
                ? widget.uid
                : name;

        final email =
            widget.data['email']
                    ?.toString()
                    .trim() ??
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
            moderation['flagged'] ==
                true;

        final attention =
            flagged ||
                accessStatus !=
                    'active' ||
                verificationStatus
                    .startsWith(
                  'pending',
                ) ||
                verificationStatus ==
                    'rejected';

        return Material(
          color: theme.brightness ==
                  Brightness.dark
              ? const Color(0xFF0D1D2B)
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
            side: BorderSide(
              color: attention
                  ? (flagged
                          ? colors.error
                          : raGold)
                      .withValues(
                      alpha: .25,
                    )
                  : colors.outlineVariant
                      .withValues(
                      alpha: .45,
                    ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              push(
                context,
                _AdminAccountScreen(
                  uid: widget.uid,
                ),
              );
            },
            child: Padding(
              padding:
                  const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior:
                        Clip.none,
                    children: [
                      ProfileInitials(
                        name: resolvedName,
                        radius: 23,
                      ),
                      if (attention)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration:
                                BoxDecoration(
                              color: flagged
                                  ? colors.error
                                  : raGold,
                              shape:
                                  BoxShape.circle,
                              border: Border.all(
                                color: theme
                                            .brightness ==
                                        Brightness
                                            .dark
                                    ? const Color(
                                        0xFF0D1D2B,
                                      )
                                    : colors
                                        .surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 11),

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
                                resolvedName,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                            ),
                            if (attention)
                              Tooltip(
                                message:
                                    'Account requires attention',
                                child: Icon(
                                  flagged
                                      ? Icons
                                          .flag_rounded
                                      : Icons
                                          .priority_high_rounded,
                                  size: 17,
                                  color: flagged
                                      ? colors.error
                                      : raGold,
                                ),
                              ),
                          ],
                        ),

                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            email,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 7.9,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _AdminStatusBadge(
                              status: role,
                            ),
                            _AdminStatusBadge(
                              status:
                                  verificationStatus,
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

                        if (validUntil !=
                                null &&
                            verification ==
                                'verified') ...[
                          const SizedBox(height: 7),

                          Row(
                            children: [
                              Icon(
                                Icons
                                    .verified_user_outlined,
                                size: 13,
                                color: colors
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Expanded(
                                child: Text(
                                  'Verification valid until '
                                  '${validUntil.day.toString().padLeft(2, '0')}/'
                                  '${validUntil.month.toString().padLeft(2, '0')}/'
                                  '${validUntil.year}',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style: GoogleFonts
                                      .plusJakartaSans(
                                    fontSize: 7.2,
                                    color: colors
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 7),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color: colors
                              .surfaceContainerHighest
                              .withValues(
                            alpha: .35,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            999,
                          ),
                        ),
                        child: Text(
                          _friendly(role),
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 6.5,
                            fontWeight:
                                FontWeight.w700,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Icon(
                        Icons
                            .chevron_right_rounded,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ],
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