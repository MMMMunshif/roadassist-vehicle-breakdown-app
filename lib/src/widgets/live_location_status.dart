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
