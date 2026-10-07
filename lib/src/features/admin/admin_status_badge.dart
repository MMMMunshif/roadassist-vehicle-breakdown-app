part of '../../screens.dart';

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final normalized =
        status.trim().toLowerCase();

    final color = switch (normalized) {
      'completed' ||
      'resolved' ||
      'verified' ||
      'active' ||
      'confirmed' =>
        raSuccess,

      'cancelled' ||
      'rejected' ||
      'suspended' ||
      'failed' ||
      'deleted' =>
        colors.error,

      'pending' ||
      'pending renewal' ||
      'under_review' ||
      'under review' ||
      'awaiting confirmation' =>
        raGold,

      'flagged' ||
      'urgent' =>
        raDanger,

      _ => colors.primary,
    };

    final icon = switch (normalized) {
      'completed' ||
      'resolved' ||
      'verified' ||
      'active' =>
        Icons.check_circle_outline_rounded,

      'cancelled' ||
      'rejected' ||
      'suspended' =>
        Icons.block_outlined,

      'flagged' ||
      'urgent' =>
        Icons.flag_outlined,

      'pending' ||
      'pending renewal' ||
      'under_review' ||
      'under review' =>
        Icons.schedule_outlined,

      _ => Icons.circle_outlined,
    };

    final label = normalized
        .replaceAll('_', ' ')
        .split(' ')
        .where(
          (word) => word.isNotEmpty,
        )
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius:
            BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: .20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label.isEmpty
                ? 'Unknown'
                : label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}