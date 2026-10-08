part of '../../screens.dart';

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({required this.status});

  final String status;

  String get normalized => status.trim().toLowerCase();

  String get label {
    final clean = normalized.replaceAll('_', ' ').trim();

    if (clean.isEmpty) {
      return 'Unknown';
    }

    return clean
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Color _tone(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return switch (normalized) {
      'verified' ||
      'approved' ||
      'active' ||
      'enabled' ||
      'online' ||
      'completed' ||
      'resolved' ||
      'paid' => raSuccess,

      'pending' ||
      'pending renewal' ||
      'pending_renewal' ||
      'searching' ||
      'waiting' ||
      'under review' ||
      'under_review' ||
      'review' ||
      'arrived' => raGold,

      'rejected' ||
      'suspended' ||
      'cancelled' ||
      'flagged' ||
      'disabled' ||
      'revoked' ||
      'dismissed' ||
      'blocked' => colors.error,

      'accepted' ||
      'en route' ||
      'en_route' ||
      'provider' ||
      'driver' ||
      'user' ||
      'account' ||
      'support' ||
      'reviewer' ||
      'super admin' ||
      'super_admin' => colors.primary,

      _ => colors.onSurfaceVariant,
    };
  }

  IconData _icon() {
    return switch (normalized) {
      'verified' || 'approved' => Icons.verified_outlined,

      'active' || 'enabled' || 'online' => Icons.check_circle_outline_rounded,

      'completed' || 'resolved' || 'paid' => Icons.task_alt_rounded,

      'pending' ||
      'pending renewal' ||
      'pending_renewal' ||
      'waiting' ||
      'review' ||
      'under review' ||
      'under_review' => Icons.hourglass_top_rounded,

      'searching' => Icons.search_rounded,

      'accepted' => Icons.handshake_outlined,

      'en route' || 'en_route' => Icons.navigation_outlined,

      'arrived' => Icons.location_on_outlined,

      'rejected' || 'cancelled' || 'dismissed' => Icons.cancel_outlined,

      'suspended' || 'disabled' || 'blocked' => Icons.block_outlined,

      'flagged' => Icons.flag_outlined,

      'revoked' => Icons.remove_circle_outline_rounded,

      'provider' => Icons.handyman_outlined,

      'driver' => Icons.directions_car_outlined,

      'support' => Icons.support_agent_outlined,

      'reviewer' => Icons.verified_user_outlined,

      'super admin' || 'super_admin' => Icons.security_outlined,

      _ => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 12, color: tone),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
