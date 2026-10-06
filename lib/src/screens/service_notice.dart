part of '../screens.dart';

class ServiceNotice extends StatelessWidget {
  const ServiceNotice({super.key});
  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appSettings')
          .doc('operations')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final notice = data?['notice'] as String? ?? '';
        final coverage = data?['coverage'] as String? ?? '';
        if (notice.isEmpty && coverage.isEmpty && data?['maintenance'] != true)
          return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data?['maintenance'] == true)
                  const Text(
                    'New assistance requests are temporarily paused.',
                    style: RaText.title,
                  ),
                if (notice.isNotEmpty) Text(notice),
                if (coverage.isNotEmpty) Text('Coverage: $coverage'),
              ],
            ),
          ),
        );
      },
    );
  }
}

bool _providerHasCurrentVerification(Map<String, dynamic> data) =>
    data['verified'] == true &&
    ((data['verificationExpiresAt'] as Timestamp?)?.toDate().isAfter(
          DateTime.now(),
        ) ??
        false);

Widget _privateDocumentPreview(String encoded, double height) {
  try {
    return Image.memory(
      base64Decode(encoded),
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) => const Text(
        'Document cannot be displayed. Request a readable replacement.',
      ),
    );
  } on FormatException {
    return const Text(
      'Invalid document encoding. Request a readable replacement.',
    );
  }
}
