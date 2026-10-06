part of '../../screens.dart';

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Operations overview', style: RaText.headline),
      const Text(
        'Live counts are capped at 100 records per card. Use each section to load more. No money or job status is changed by a complaint decision.',
      ),
      for (final section in [
        'users',
        'providerDirectory',
        'requests',
        'accountModeration',
      ])
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(section)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Text('Could not load $section. Check admin access.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final records = snapshot.data!.docs;
            final count = section == 'providerDirectory'
                ? records
                      .where(
                        (d) =>
                            d.data()['online'] == true &&
                            _providerHasCurrentVerification(d.data()),
                      )
                      .length
                : section == 'requests'
                ? records
                      .where(
                        (d) => [
                          'accepted',
                          'en_route',
                          'arrived',
                        ].contains(d.data()['status']),
                      )
                      .length
                : section == 'accountModeration'
                ? records.where((d) => d.data()['flagged'] == true).length
                : records.length;
            return Card(
              child: ListTile(
                title: Text(
                  {
                    'users': 'Users loaded',
                    'providerDirectory': 'Online providers in loaded records',
                    'requests': 'Active jobs in loaded records',
                    'accountModeration': 'Flagged accounts in loaded records',
                  }[section]!,
                ),
                trailing: Text('$count', style: RaText.numeric),
              ),
            );
          },
        ),
    ],
  );
}
