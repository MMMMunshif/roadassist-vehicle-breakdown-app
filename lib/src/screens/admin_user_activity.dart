part of '../screens.dart';

class _AdminUserActivity extends StatelessWidget {
  const _AdminUserActivity({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final field in ['driverId', 'providerId'])
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where(field, isEqualTo: uid)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text('Could not load related jobs.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return ExpansionTile(
              title: Text(
                '${field == 'driverId' ? 'Driver' : 'Provider'} jobs (${snapshot.data!.docs.length}; up to 50 shown)',
              ),
              children: [
                for (final doc in snapshot.data!.docs)
                  ListTile(
                    title: Text('${doc.data()['service'] ?? doc.id}'),
                    subtitle: Text(
                      '${doc.data()['status']} • Payment ${doc.data()['providerConfirmedPayment'] == true ? 'confirmed' : 'unconfirmed'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _AdminComplaintScreen(requestId: doc.id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('cancelledBy', isEqualTo: uid)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) => ExpansionTile(
          title: Text(
            'Cancellations by this account (${snapshot.data?.docs.length ?? 0}; up to 50 shown)',
          ),
          children: [
            if (snapshot.hasError)
              const Text('Could not load cancellation history.'),
            for (final doc
                in snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              ListTile(
                title: Text('${doc.data()['cancellationType']}'),
                subtitle: Text(
                  '${doc.data()['cancellationReason']}\nJob: ${doc.id}',
                ),
              ),
          ],
        ),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('adminAudit')
            .where('target', isEqualTo: uid)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) => ExpansionTile(
          title: const Text('Account audit history (up to 50 entries)'),
          children: [
            if (snapshot.hasError) const Text('Could not load audit history.'),
            for (final doc
                in snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              ListTile(
                title: Text(
                  '${doc.data()['kind']} • ${doc.data()['state'] ?? ''}',
                ),
                subtitle: Text(
                  '${doc.data()['reason'] ?? ''}\nActor: ${doc.data()['actor']}',
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
