part of '../../screens.dart';

/// RoadAssist admin overview.
///
/// Live metrics and operational indicators are implemented in
/// [_AdminOverview].
class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({
    super.key,
    this.canReviewProviders = false,
    this.onReviewProviders,
  });
  final bool canReviewProviders;
  final VoidCallback? onReviewProviders;

  @override
  Widget build(BuildContext context) {
    return _AdminOverview(
      canReviewProviders: canReviewProviders,
      onReviewProviders: onReviewProviders,
    );
  }
}
