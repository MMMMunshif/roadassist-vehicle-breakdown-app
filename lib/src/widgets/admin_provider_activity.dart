part of '../screens.dart';

/// Live, bounded operational indicators. No sample values are displayed.
class AdminProviderActivity extends StatefulWidget {
  const AdminProviderActivity({super.key, this.onReview});
  final VoidCallback? onReview;
  @override
  State<AdminProviderActivity> createState() => _AdminProviderActivityState();
}

class _AdminProviderActivityState extends State<AdminProviderActivity> {
  late final applications = FirebaseFirestore.instance
      .collection('providerApplications')
      .orderBy('submittedAt', descending: true)
      .limit(100)
      .snapshots();
  late final moderation = FirebaseFirestore.instance
      .collection('accountModeration')
      .snapshots();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: applications,
        builder: (context, a) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: moderation,
              builder: (context, m) {
                if (a.hasError || m.hasError)
                  return const InlineMessage(
                    icon: Icons.cloud_off_outlined,
                    text: 'Provider activity could not be loaded.',
                  );
                if (!a.hasData || !m.hasData)
                  return const LinearProgressIndicator();
                final reviews = {for (final d in m.data!.docs) d.id: d.data()};
                final now = DateTime.now();
                var pending = 0, corrections = 0;
                for (final d in a.data!.docs) {
                  final data = d.data(), review = reviews[d.id];
                  if (data['applicationStatus'] == 'withdrawn') continue;
                  if (ProviderDocumentCorrection.active(data, review) != null) {
                    corrections++;
                    continue;
                  }
                  if (review?['verification'] == 'rejected') continue;
                  final expiry = review?['validUntil'];
                  if (review?['verification'] == 'verified' &&
                      review?['verificationRevision'] == data['revision'] &&
                      expiry is Timestamp &&
                      expiry.toDate().isAfter(now))
                    continue;
                  pending++;
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(Icons.notifications_active_outlined),
                            Text(
                              '$pending applications awaiting review',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (widget.onReview != null)
                              TextButton(
                                onPressed: widget.onReview,
                                child: const Text('Review providers'),
                              ),
                          ],
                        ),
                        if (corrections > 0)
                          Text('$corrections awaiting corrected documents'),
                        const Text(
                          'Pending count covers the latest 100 applications.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      );
}
