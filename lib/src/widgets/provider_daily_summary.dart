part of '../screens.dart';

/// One source of truth for the compact dashboard: only confirmed money is
/// labelled collected; service completion and driver ratings remain separate.
class RaProviderDailySummary extends StatelessWidget {
  const RaProviderDailySummary({super.key, this.jobs, this.today});
  final List<ProviderJob>? jobs;
  final DateTime? today;
  @override
  Widget build(BuildContext context) {
    if (jobs != null) return _summary(context, jobs!);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchProviderRequests() : null,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Unable to load today\'s earnings.',
          );
        if (!snapshot.hasData)
          return const RaProviderCard(child: LinearProgressIndicator());
        return _summary(
          context,
          snapshot.data!.docs.map((d) => ProviderJob(d.id, d.data())).toList(),
        );
      },
    );
  }

  Widget _summary(BuildContext context, List<ProviderJob> values) {
    final now = today ?? DateTime.now();
    final analytics = ProviderAnalytics(values, now, now);
    final rating = analytics.averageRating;
    Widget metric(String title, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _providerText(context, size: 12, muted: true)),
        const SizedBox(height: 6),
        Text(
          value,
          style: _providerText(context, size: 18, weight: FontWeight.w800),
        ),
      ],
    );
    return RaProviderCard(
      child: LayoutBuilder(
        builder: (context, box) {
          final revenue = metric(
            'Collected today',
            _businessMoney(analytics.revenue),
          );
          final completed = metric('Jobs', '${analytics.completed.length}');
          final reviewed = metric(
            'Rating',
            rating == null ? 'No ratings' : rating.toStringAsFixed(1),
          );
          if (box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                revenue,
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: completed),
                    Expanded(child: reviewed),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: revenue),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: completed),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: reviewed),
            ],
          );
        },
      ),
    );
  }
}
