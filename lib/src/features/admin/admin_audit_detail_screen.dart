part of '../../screens.dart';

class _AdminAuditScreen extends StatelessWidget {
  const _AdminAuditScreen({
    required this.data,
  });

  final Map<String, dynamic> data;

  String _formatDate(
    DateTime value,
  ) {
    final local =
        value.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} • '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatValue(
    dynamic value,
  ) {
    if (value == null) {
      return 'Not recorded';
    }

    if (value is Timestamp) {
      return _formatDate(
        value.toDate(),
      );
    }

    if (value is DateTime) {
      return _formatDate(
        value,
      );
    }

    if (value is bool) {
      return value
          ? 'Yes'
          : 'No';
    }

    if (value is Map) {
      if (value.isEmpty) {
        return 'No values recorded';
      }

      return value.entries
          .map(
            (
              entry,
            ) =>
                '${_friendlyKey(entry.key.toString())}: ${_formatValue(entry.value)}',
          )
          .join('\n');
    }

    if (value is List) {
      if (value.isEmpty) {
        return 'No values recorded';
      }

      return value
          .map(
            _formatValue,
          )
          .join('\n');
    }

    final text =
        value.toString().trim();

    return text.isEmpty
        ? 'Not recorded'
        : text;
  }

  String _friendlyKey(
    String value,
  ) {
    final separated =
        value
            .replaceAll(
              RegExp(
                r'([a-z0-9])([A-Z])',
              ),
              r'$1 $2',
            )
            .replaceAll(
              '_',
              ' ',
            )
            .trim();

    if (separated.isEmpty) {
      return 'Unknown';
    }

    return separated
        .split(' ')
        .where(
          (part) =>
              part.isNotEmpty,
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

    final kind =
        _formatValue(
      data['kind'],
    );

    final target =
        _formatValue(
      data['target'],
    );

    final actor =
        _formatValue(
      data['actor'],
    );

    final reason =
        _formatValue(
      data['reason'],
    );

    final createdAt =
        _formatValue(
      data['createdAt'],
    );

    final hasBefore =
        data['before'] !=
            null;

    final hasAfter =
        data['after'] !=
            null;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Audit Record',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
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
          _RaAdminAuditHero(
            kind: kind,
            createdAt:
                createdAt,
          ),

          const SizedBox(height: 13),

          const _RaAdminAuditNotice(
            icon:
                Icons.lock_outline_rounded,
            title:
                'Read-only audit record',
            message:
                'This record provides traceability for an administrative action. It cannot be changed from this screen.',
            tone:
                raBlue,
          ),

          const SizedBox(height: 23),

          const _RaAdminAuditHeading(
            title:
                'Audit information',
            subtitle:
                'Recorded administrative action, affected target and administrator identity.',
          ),

          const SizedBox(height: 10),

          _RaAdminAuditSurface(
            child: Column(
              children: [
                _RaAdminAuditDetailField(
                  icon:
                      Icons.category_outlined,
                  label:
                      'Action',
                  value:
                      kind,
                ),

                const Divider(
                  height: 1,
                ),

                _RaAdminAuditDetailField(
                  icon: Icons
                      .center_focus_strong_outlined,
                  label:
                      'Target',
                  value:
                      target,
                  selectable:
                      true,
                ),

                const Divider(
                  height: 1,
                ),

                _RaAdminAuditDetailField(
                  icon: Icons
                      .admin_panel_settings_outlined,
                  label:
                      'Actor',
                  value:
                      actor,
                  selectable:
                      true,
                ),

                const Divider(
                  height: 1,
                ),

                _RaAdminAuditDetailField(
                  icon:
                      Icons.schedule_outlined,
                  label:
                      'Created',
                  value:
                      createdAt,
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          _RaAdminAuditDetailTextCard(
            title: 'Reason',
            icon:
                Icons.notes_outlined,
            value: reason,
            tone:
                colors.primary,
          ),

          if (hasBefore ||
              hasAfter) ...[
            const SizedBox(height: 23),

            const _RaAdminAuditHeading(
              title:
                  'Recorded change',
              subtitle:
                  'Before and after values written to the audit event when available.',
            ),

            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final desktop =
                    constraints.maxWidth >=
                        650;

                final before =
                    hasBefore
                        ? _RaAdminAuditDetailTextCard(
                            title:
                                'Before',
                            icon: Icons
                                .history_toggle_off_outlined,
                            value:
                                _formatValue(
                              data[
                                  'before'],
                            ),
                            tone:
                                raGold,
                          )
                        : null;

                final after =
                    hasAfter
                        ? _RaAdminAuditDetailTextCard(
                            title:
                                'After',
                            icon:
                                Icons.update_outlined,
                            value:
                                _formatValue(
                              data[
                                  'after'],
                            ),
                            tone:
                                raSuccess,
                          )
                        : null;

                if (!desktop) {
                  return Column(
                    children: [
                      if (before !=
                          null)
                        before,
                      if (before !=
                              null &&
                          after !=
                              null)
                        const SizedBox(
                          height: 10,
                        ),
                      if (after !=
                          null)
                        after,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    if (before !=
                        null)
                      Expanded(
                        child:
                            before,
                      ),
                    if (before !=
                            null &&
                        after !=
                            null)
                      const SizedBox(
                        width: 10,
                      ),
                    if (after !=
                        null)
                      Expanded(
                        child:
                            after,
                      ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 22),

          _RaAdminAuditMetadata(
            data:
                data,
            formatter:
                _formatValue,
            friendlyKey:
                _friendlyKey,
          ),
        ],
      ),
    );
  }
}

class _RaAdminAuditHero
    extends StatelessWidget {
  const _RaAdminAuditHero({
    required this.kind,
    required this.createdAt,
  });

  final String kind;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
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
            BorderRadius.circular(23),
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
              Icons.history_rounded,
              color:
                  Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  kind,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    color:
                        Colors.white,
                    fontSize: 17,
                    height: 1.2,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .schedule_outlined,
                      size: 13,
                      color:
                          Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        createdAt,
                        style: GoogleFonts
                            .plusJakartaSans(
                          color:
                              Colors.white70,
                          fontSize: 7.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
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
              'AUDIT',
              style: GoogleFonts
                  .plusJakartaSans(
                color:
                    Colors.white,
                fontSize: 6.8,
                fontWeight:
                    FontWeight.w800,
                letterSpacing:
                    .6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminAuditHeading
    extends StatelessWidget {
  const _RaAdminAuditHeading({
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

class _RaAdminAuditSurface
    extends StatelessWidget {
  const _RaAdminAuditSurface({
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
          const EdgeInsets.all(14),
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

class _RaAdminAuditDetailField
    extends StatelessWidget {
  const _RaAdminAuditDetailField({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final valueStyle =
        GoogleFonts.plusJakartaSans(
      fontSize: 9,
      height: 1.4,
      fontWeight:
          FontWeight.w700,
    );

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final compact =
              constraints.maxWidth <
                  420;

          final labelWidget = Row(
            children: [
              Icon(
                icon,
                size: 17,
                color:
                    colors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w700,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          );

          final valueWidget =
              selectable
                  ? SelectableText(
                      value,
                      style:
                          valueStyle,
                    )
                  : Text(
                      value,
                      textAlign:
                          compact
                              ? TextAlign.left
                              : TextAlign.right,
                      style:
                          valueStyle,
                    );

          if (compact) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 6),
                valueWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 135,
                child:
                    labelWidget,
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Align(
                  alignment:
                      Alignment.centerRight,
                  child:
                      valueWidget,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RaAdminAuditDetailTextCard
    extends StatelessWidget {
  const _RaAdminAuditDetailTextCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.tone,
  });

  final String title;
  final IconData icon;
  final String value;
  final Color tone;

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
            : colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(
                    alpha: .07,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: tone,
                ),
              ),

              const SizedBox(width: 9),

              Text(
                title,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          SelectableText(
            value,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 8.8,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminAuditNotice
    extends StatelessWidget {
  const _RaAdminAuditNotice({
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
            size: 18,
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
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.9,
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

class _RaAdminAuditMetadata
    extends StatelessWidget {
  const _RaAdminAuditMetadata({
    required this.data,
    required this.formatter,
    required this.friendlyKey,
  });

  final Map<String, dynamic> data;

  final String Function(dynamic)
      formatter;

  final String Function(String)
      friendlyKey;

  @override
  Widget build(BuildContext context) {
    const knownKeys = {
      'kind',
      'target',
      'actor',
      'reason',
      'createdAt',
      'before',
      'after',
    };

    final additional =
        data.entries
            .where(
              (
                entry,
              ) =>
                  !knownKeys.contains(
                entry.key,
              ),
            )
            .toList();

    if (additional.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const _RaAdminAuditHeading(
          title:
              'Additional metadata',
          subtitle:
              'Other fields stored with this audit event.',
        ),

        const SizedBox(height: 10),

        _RaAdminAuditSurface(
          child: Column(
            children: [
              for (var index = 0;
                  index <
                      additional.length;
                  index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                  ),

                _RaAdminAuditDetailField(
                  icon: Icons
                      .data_object_outlined,
                  label:
                      friendlyKey(
                    additional[index]
                        .key,
                  ),
                  value:
                      formatter(
                    additional[index]
                        .value,
                  ),
                  selectable:
                      true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}