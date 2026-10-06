part of '../../screens.dart';

class _AdminUserRow extends StatefulWidget {
  const _AdminUserRow({
    super.key,
    required this.uid,
    required this.data,
    required this.pendingOnly,
  });
  final String uid;
  final Map<String, dynamic> data;
  final bool pendingOnly;
  @override
  State<_AdminUserRow> createState() => _AdminUserRowState();
}

class _AdminUserRowState extends State<_AdminUserRow> {
  late final review = FirebaseFirestore.instance
      .collection('accountModeration')
      .doc(widget.uid)
      .snapshots();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: review,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const ListTile(title: Text('Could not load account review.'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!.data() ?? {};
      final status =
          data['verification'] == 'verified' &&
              !((data['validUntil'] as Timestamp?)?.toDate().isAfter(
                    DateTime.now(),
                  ) ??
                  false)
          ? 'pending renewal'
          : data['verification'] ?? 'pending';
      if (widget.pendingOnly && !status.toString().startsWith('pending'))
        return const SizedBox.shrink();
      return ListTile(
        title: Text(widget.data['displayName'] as String? ?? widget.uid),
        subtitle: Text(
          '${widget.data['email'] ?? ''}\n${widget.data['role']} / $status / ${data['status'] ?? 'active'}${data['flagged'] == true ? ' / Flagged' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => push(context, _AdminAccountScreen(uid: widget.uid)),
      );
    },
  );
}
