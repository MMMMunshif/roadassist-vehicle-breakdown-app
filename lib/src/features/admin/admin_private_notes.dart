part of '../../screens.dart';

class _AdminPrivateNotes extends StatefulWidget {
  const _AdminPrivateNotes({
    required this.kind,
    required this.target,
  });

  final String kind;
  final String target;

  @override
  State<_AdminPrivateNotes> createState() =>
      _AdminPrivateNotesState();
}

class _AdminPrivateNotesState
    extends State<_AdminPrivateNotes> {
  bool busy = false;

  late final notes = FirebaseFirestore.instance
      .collection('adminNotes')
      .where(
        'kind',
        isEqualTo: widget.kind,
      )
      .where(
        'target',
        isEqualTo: widget.target,
      )
      .limit(50)
      .snapshots();

  Future<void> add() async {
    final text = await _adminReason(
      context,
      'Private admin note',
    );

    if (text == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService().addPrivateNote(
        widget.kind,
        widget.target,
        text,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save private note.',
          ),
          backgroundColor: raDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.note_alt_outlined,
                  color:
                      colors.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: RaSpace.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private admin notes',
                      style: theme
                          .textTheme.titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Visible only to administrators. Saved notes cannot be edited.',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: RaSpace.md),

          OutlinedButton.icon(
            onPressed:
                busy ? null : add,
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.add_comment_outlined,
                  ),
            label: Text(
              busy
                  ? 'Saving Note…'
                  : 'Add Private Note',
            ),
          ),

          const SizedBox(height: RaSpace.md),

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: notes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(
                    RaSpace.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer
                        .withValues(alpha: .35),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Could not load private notes.',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(
                    RaSpace.lg,
                  ),
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                );
              }

              final entries =
                  snapshot.data!.docs.toList();

              entries.sort((a, b) {
                final aTime =
                    a.data()['createdAt']
                        as Timestamp?;

                final bTime =
                    b.data()['createdAt']
                        as Timestamp?;

                if (aTime == null &&
                    bTime == null) {
                  return 0;
                }

                if (aTime == null) return 1;
                if (bTime == null) return -1;

                return bTime.compareTo(aTime);
              });

              if (entries.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(
                    RaSpace.lg,
                  ),
                  decoration: BoxDecoration(
                    color: colors
                        .surfaceContainerHighest
                        .withValues(alpha: .30),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons
                            .speaker_notes_off_outlined,
                      ),
                      SizedBox(
                        height: RaSpace.sm,
                      ),
                      Text(
                        'No private notes recorded.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0;
                      index <
                          entries.length;
                      index++) ...[
                    _AdminPrivateNoteTile(
                      data:
                          entries[index].data(),
                    ),
                    if (index !=
                        entries.length - 1)
                      const Divider(),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminPrivateNoteTile
    extends StatelessWidget {
  const _AdminPrivateNoteTile({
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final text =
        data['text'] as String? ?? '';

    final actor =
        data['actor']?.toString() ??
            'Unknown administrator';

    final timestamp =
        data['createdAt'] as Timestamp?;

    final date = timestamp == null
        ? 'Time not recorded'
        : timestamp
            .toDate()
            .toLocal()
            .toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: RaSpace.md,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color:
                  colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$actor • $date',
                  style: theme
                      .textTheme.labelSmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}