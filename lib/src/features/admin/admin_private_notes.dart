part of '../../screens.dart';

class _AdminPrivateNotes extends StatefulWidget {
  const _AdminPrivateNotes({required this.kind, required this.target});
  final String kind, target;
  @override
  State<_AdminPrivateNotes> createState() => _AdminPrivateNotesState();
}

class _AdminPrivateNotesState extends State<_AdminPrivateNotes> {
  bool busy = false;
  late final notes = FirebaseFirestore.instance
      .collection('adminNotes')
      .where('kind', isEqualTo: widget.kind)
      .where('target', isEqualTo: widget.target)
      .limit(50)
      .snapshots();
  Future<void> add() async {
    final text = await _adminReason(context, 'Private admin note');
    if (text == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().addPrivateNote(widget.kind, widget.target, text);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save private note.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const Text('Private admin notes', style: RaText.title),
      const Text(
        'Visible only to admins; notes cannot be edited. Up to 50 loaded per case.',
      ),
      OutlinedButton(
        onPressed: busy ? null : add,
        child: const Text('Add private note'),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notes,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Text('Could not load private notes.');
          final entries = snapshot.data?.docs.toList() ?? [];
          entries.sort(
            (a, b) => (b.data()['createdAt'] as Timestamp).compareTo(
              a.data()['createdAt'] as Timestamp,
            ),
          );
          return Column(
            children: [
              for (final note in entries)
                ListTile(
                  title: Text(note.data()['text'] as String),
                  subtitle: Text(
                    '${note.data()['actor']} / ${(note.data()['createdAt'] as Timestamp).toDate().toLocal()}',
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
