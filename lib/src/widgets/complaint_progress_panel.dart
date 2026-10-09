part of '../screens.dart';

class ComplaintProgressPanel extends StatelessWidget {
  const ComplaintProgressPanel({super.key, required this.requestId});
  final String requestId;
  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('complaintReviews')
        .doc(requestId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Support review status is temporarily unavailable.',
          );
        final review = snapshot.data?.data();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Support review',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  review == null
                      ? 'Submitted - waiting for support review'
                      : 'Status: ${AdminAuditPresentation.friendlyKey(review['status']?.toString() ?? 'open')}',
                ),
                if (review?['decision'] is String &&
                    (review!['decision'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(review['decision'] as String),
                ],
                if (review?['updatedAt'] is Timestamp)
                  Text(
                    'Updated: ${(review!['updatedAt'] as Timestamp).toDate().toLocal().toString().substring(0, 16)}',
                  ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref
                      .collection('history')
                      .orderBy('createdAt', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, events) {
                    if (events.hasError)
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Review history is temporarily unavailable.',
                        ),
                      );
                    final rows = events.data?.docs ?? [];
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Review history (latest 30)'),
                      children: [
                        for (final row in rows)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history_rounded),
                            title: Text(
                              AdminAuditPresentation.friendlyKey(
                                row.data()['status']?.toString() ?? 'open',
                              ),
                            ),
                            subtitle: Text(
                              '${row.data()['decision'] ?? ''}\n${row.data()['createdAt'] is Timestamp ? (row.data()['createdAt'] as Timestamp).toDate().toLocal().toString().substring(0, 16) : 'Saving...'}',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
