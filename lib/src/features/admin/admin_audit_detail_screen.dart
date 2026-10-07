part of '../../screens.dart';

class _AdminAuditScreen extends StatelessWidget {
  const _AdminAuditScreen({
    required this.data,
  });

  final Map<String, dynamic> data;

  String _formatValue(dynamic value) {
    if (value == null) {
      return 'Not recorded';
    }

    if (value is Timestamp) {
      return value.toDate().toLocal().toString();
    }

    if (value is Map || value is List) {
      return value.toString();
    }

    final text = value.toString().trim();

    return text.isEmpty
        ? 'Not recorded'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final kind =
        _formatValue(data['kind']);

    final target =
        _formatValue(data['target']);

    final actor =
        _formatValue(data['actor']);

    final reason =
        _formatValue(data['reason']);

    final createdAt =
        _formatValue(data['createdAt']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Record'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(
              RaSpace.xl,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant
                    .withValues(alpha: .55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color:
                        colors.onPrimaryContainer,
                    size: 27,
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
                        kind,
                        style: theme
                            .textTheme.titleLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        createdAt,
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RaSpace.xl),

          Text(
            'Audit information',
            style: theme.textTheme.titleLarge
                ?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: RaSpace.md),

          Container(
            padding: const EdgeInsets.all(
              RaSpace.lg,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant
                    .withValues(alpha: .55),
              ),
            ),
            child: Column(
              children: [
                _AdminAuditField(
                  icon: Icons.category_outlined,
                  label: 'Action',
                  value: kind,
                ),
                const Divider(height: 1),
                _AdminAuditField(
                  icon: Icons
                      .center_focus_strong_outlined,
                  label: 'Target',
                  value: target,
                  selectable: true,
                ),
                const Divider(height: 1),
                _AdminAuditField(
                  icon: Icons
                      .admin_panel_settings_outlined,
                  label: 'Actor',
                  value: actor,
                  selectable: true,
                ),
                const Divider(height: 1),
                _AdminAuditField(
                  icon: Icons.schedule_outlined,
                  label: 'Created',
                  value: createdAt,
                ),
              ],
            ),
          ),

          const SizedBox(height: RaSpace.md),

          _AdminAuditTextCard(
            title: 'Reason',
            icon: Icons.notes_outlined,
            value: reason,
          ),

          if (data['before'] != null) ...[
            const SizedBox(height: RaSpace.md),
            _AdminAuditTextCard(
              title: 'Before',
              icon:
                  Icons.history_toggle_off_outlined,
              value:
                  _formatValue(data['before']),
            ),
          ],

          if (data['after'] != null) ...[
            const SizedBox(height: RaSpace.md),
            _AdminAuditTextCard(
              title: 'After',
              icon: Icons.update_outlined,
              value:
                  _formatValue(data['after']),
            ),
          ],

          const SizedBox(height: RaSpace.md),

          Container(
            padding: const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: .32),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                ),
                SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Text(
                    'Audit records provide traceability for administrative actions and should not be modified from this screen.',
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

class _AdminAuditField extends StatelessWidget {
  const _AdminAuditField({
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final valueWidget = selectable
        ? SelectableText(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
        : Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: RaSpace.md,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: RaSpace.md),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: valueWidget,
          ),
        ],
      ),
    );
  }
}

class _AdminAuditTextCard extends StatelessWidget {
  const _AdminAuditTextCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(
                width: RaSpace.sm,
              ),
              Text(
                title,
                style: theme
                    .textTheme.titleSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: RaSpace.md,
          ),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}