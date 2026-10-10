part of '../../screens.dart';

class _AdminPrivateNotes extends StatefulWidget {
  const _AdminPrivateNotes({required this.kind, required this.target});

  final String kind;
  final String target;

  @override
  State<_AdminPrivateNotes> createState() => _AdminPrivateNotesState();
}

class _AdminPrivateNotesState extends State<_AdminPrivateNotes> {
  bool busy = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> notes =
      FirebaseFirestore.instance
          .collection('adminNotes')
          .where('kind', isEqualTo: widget.kind)
          .where('target', isEqualTo: widget.target)
          .limit(50)
          .snapshots();

  Future<void> add() async {
    final text = await _adminReason(context, 'Private admin note');

    if (text == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService().addPrivateNote(widget.kind, widget.target, text);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private admin note saved.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save private note.'),
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.note_alt_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private admin notes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Visible only to administrators. Saved notes are append-only and cannot be edited from this workspace.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: raGold.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, color: raGold, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Use notes for internal operational context only. Avoid unnecessary identity, medical, payment-card or other highly sensitive information.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: OutlinedButton.icon(
              onPressed: busy ? null : add,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_comment_outlined),
              label: Text(busy ? 'Saving Note…' : 'Add Private Note'),
            ),
          ),

          const SizedBox(height: 12),

          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .40),
          ),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: notes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(15),
                  child: _RaAdminPrivateNotesMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to load notes',
                    message: 'Check administrator permission and connection.',
                    tone: raDanger,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final entries = snapshot.data!.docs.toList();

              entries.sort((first, second) {
                final firstTime = first.data()['createdAt'] as Timestamp?;

                final secondTime = second.data()['createdAt'] as Timestamp?;

                if (firstTime == null && secondTime == null) {
                  return 0;
                }

                if (firstTime == null) {
                  return 1;
                }

                if (secondTime == null) {
                  return -1;
                }

                return secondTime.compareTo(firstTime);
              });

              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: _RaAdminPrivateNotesEmpty(),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(15, 7, 15, 15),
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      _RaAdminPrivateNoteTile(data: entries[index].data()),
                      if (index != entries.length - 1)
                        Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: .35),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RaAdminPrivateNoteTile extends StatelessWidget {
  const _RaAdminPrivateNoteTile({required this.data});

  final Map<String, dynamic> data;

  String _date(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Time not recorded';
    }

    final value = timestamp.toDate().toLocal();

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} • '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final text = data['text']?.toString() ?? '';

    final actor = data['actor']?.toString() ?? 'Unknown administrator';

    final timestamp = data['createdAt'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .40),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 17,
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.trim().isEmpty ? 'Empty note' : text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 7),

                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _RaAdminPrivateNoteMeta(
                      icon: Icons.admin_panel_settings_outlined,
                      text: actor,
                    ),
                    _RaAdminPrivateNoteMeta(
                      icon: Icons.schedule_outlined,
                      text: _date(timestamp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminPrivateNoteMeta extends StatelessWidget {
  const _RaAdminPrivateNoteMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminPrivateNotesEmpty extends StatelessWidget {
  const _RaAdminPrivateNotesEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(
          Icons.speaker_notes_off_outlined,
          size: 28,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(height: 7),
        Text(
          'No private notes recorded.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaAdminPrivateNotesMessage extends StatelessWidget {
  const _RaAdminPrivateNotesMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
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
