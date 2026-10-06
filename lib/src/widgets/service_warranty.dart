part of '../screens.dart';

String _warrantyLabel(Map<String, dynamic> offer) {
  final days = (offer['warrantyDays'] as num?)?.toInt();
  if (days == null) return 'Warranty was not recorded for this older offer.';
  if (days == 0) return 'No service warranty offered.';
  return 'Service warranty: $days days. Coverage / exclusions: ${offer['warrantyTerms']}';
}

class ServiceWarranty extends StatelessWidget {
  const ServiceWarranty({
    super.key,
    required this.requestId,
    required this.job,
  });
  final String requestId;
  final Map<String, dynamic> job;
  @override
  Widget build(BuildContext context) {
    final revision = job['approvedRepairId'] as String?;
    final quote = revision ?? job['selectedQuoteId'] as String?;
    if (quote == null)
      return const Text(
        'No warranty was recorded for this job. You can still report a service problem.',
      );
    final ref = FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .collection(revision == null ? 'quotes' : 'repairQuotes')
        .doc(quote);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Text('Could not load agreed warranty terms.');
        final offer = snapshot.data?.data();
        if (offer == null) return const LinearProgressIndicator();
        final days = (offer['warrantyDays'] as num?)?.toInt() ?? 0;
        final completed = (job['completedAt'] as Timestamp?)?.toDate();
        final expires = completed?.add(Duration(days: days));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_warrantyLabel(offer)),
            if (days > 0 && expires != null)
              Text(
                'Ends: ${expires.toLocal().toString().split('.').first}. ${DateTime.now().isBefore(expires) ? 'Within warranty period' : 'Warranty period ended'}',
              ),
            const Text(
              'A repeated problem needs review against the agreed coverage. No automatic refund or new charge is applied.',
            ),
          ],
        );
      },
    );
  }
}
