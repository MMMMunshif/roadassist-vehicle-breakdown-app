part of '../screens.dart';

class LiveLocationStatus extends StatelessWidget {
  const LiveLocationStatus({
    super.key,
    this.updatedAt,
    required this.hasPosition,
    this.distanceKm,
  });
  final DateTime? updatedAt;
  final bool hasPosition;
  final double? distanceKm;
  @override
  Widget build(BuildContext context) {
    final fresh =
        hasPosition && LocationFreshness.isFresh(updatedAt, DateTime.now());
    return InlineMessage(
      icon: fresh ? Icons.location_on_outlined : Icons.location_off_outlined,
      text:
          '${LocationFreshness.label(hasPosition ? updatedAt : null, DateTime.now())}${fresh && distanceKm != null ? ' | ${distanceKm!.toStringAsFixed(1)} km away (straight-line)' : ''}${fresh ? '' : ' Live position and ETA may be outdated.'}',
    );
  }
}

/// Firestore cache metadata is distinguished from a proven network disconnect.
class RequestSyncStatus extends StatelessWidget {
  const RequestSyncStatus({
    super.key,
    required this.showingSavedData,
    this.lastSynced,
  });
  final bool showingSavedData;
  final DateTime? lastSynced;
  @override
  Widget build(BuildContext context) {
    if (!showingSavedData) return const SizedBox.shrink();
    final time = lastSynced == null
        ? null
        : TimeOfDay.fromDateTime(lastSynced!.toLocal()).format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InlineMessage(
        icon: Icons.sync_outlined,
        text:
            'Showing saved request details. ${time == null ? 'No server update received in this session.' : 'Last server update: $time.'} Waiting for a server connection; status may have changed.',
      ),
    );
  }
}
