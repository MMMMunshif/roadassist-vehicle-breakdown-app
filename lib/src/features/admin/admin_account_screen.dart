part of '../../screens.dart';

class _AdminAccountScreen extends StatefulWidget {
  const _AdminAccountScreen({required this.uid});
  final String uid;
  @override
  State<_AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<_AdminAccountScreen> {
  bool busy = false;
  late final user = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  late final moderation = FirebaseFirestore.instance
      .collection('accountModeration')
      .doc(widget.uid)
      .snapshots();
  Future<void> change(String action) async {
    final reason = await _adminReason(context, '$action account');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().moderate(
        widget.uid,
        reason: reason,
        verification: action == 'Verify'
            ? 'verified'
            : action == 'Reject'
            ? 'rejected'
            : null,
        status: action == 'Suspend'
            ? 'suspended'
            : action == 'Restore'
            ? 'active'
            : null,
        flagged: action == 'Flag'
            ? true
            : action == 'Clear flag'
            ? false
            : null,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Action failed. Check admin permission and connection.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    final reason = await _adminReason(
      context,
      'Deletion reason (job, payment and complaint records are retained)',
    );
    if (reason == null || !mounted) return;
    final confirmation = await _adminReason(
      context,
      'Confirm permanent deletion',
      expectedId: widget.uid,
    );
    if (confirmation != widget.uid || !mounted) return;
    setState(() => busy = true);
    try {
      await AdminService().deleteAccount(widget.uid, reason, confirmation!);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account review')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user,
      builder: (context, snapshot) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: moderation,
        builder: (context, review) {
          if (snapshot.hasError || review.hasError)
            return const Center(child: Text('Could not load account.'));
          if (!snapshot.hasData || !review.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data();
          if (data == null)
            return const Center(child: Text('Profile no longer exists.'));
          final decision = review.data!.data() ?? {};
          final own = FirebaseAuth.instance.currentUser?.uid == widget.uid;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                data['displayName'] as String? ?? widget.uid,
                style: RaText.headline,
              ),
              SummaryRow('Email', data['email'] as String? ?? ''),
              SummaryRow('Phone', data['phone'] as String? ?? ''),
              SummaryRow('Role', data['role'] as String? ?? ''),
              SummaryRow('Access', decision['status'] as String? ?? 'active'),
              SummaryRow(
                'Verification',
                decision['verification'] as String? ?? 'pending',
              ),
              SummaryRow('Flagged', '${decision['flagged'] ?? false}'),
              if (decision['reason'] != null)
                Text('Last reason: ${decision['reason']}'),
              const Text(
                'Suspension blocks app database operations. It does not disable Firebase login. Check active jobs before suspending a participant.',
              ),
              if (data['role'] == 'provider') ...[
                Text(
                  'Services: ${(data['services'] as List? ?? []).join(', ')}',
                ),
                if (data['photoData'] is String)
                  RevisionEvidencePhotos(photos: [data['photoData'] as String]),
                const Text(
                  'Review the private application and complete the checklist before approving.',
                ),
              ],
              Wrap(
                spacing: 8,
                children: [
                  for (final action in [
                    'Suspend',
                    'Restore',
                    'Flag',
                    'Clear flag',
                  ])
                    OutlinedButton(
                      onPressed:
                          busy ||
                              (own && ['Suspend', 'Reject'].contains(action))
                          ? null
                          : () => change(action),
                      child: Text(action),
                    ),
                ],
              ),
              if (data['role'] == 'provider')
                _AdminVerificationPanel(uid: widget.uid),
              _AdminUserActivity(uid: widget.uid),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('adminAccess')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
                builder: (context, access) {
                  final role = access.data?.data()?['role'] ?? 'super_admin';
                  if (!access.hasData || role != 'super_admin')
                    return const SizedBox.shrink();
                  return OutlinedButton.icon(
                    onPressed: busy || own ? null : deleteAccount,
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Delete account permanently'),
                  );
                },
              ),
              const Text(
                'Deletion removes login, profile, vehicles, device tokens and verification documents. Job, payment, complaint and audit records remain. Active jobs, unconfirmed payments and unresolved complaints block deletion.',
              ),
              _AdminPrivateNotes(kind: 'account', target: widget.uid),
              if (busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    ),
  );
}
