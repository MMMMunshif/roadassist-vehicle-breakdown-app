part of '../screens.dart';

class _AdminVerificationPanel extends StatefulWidget {
  const _AdminVerificationPanel({required this.uid});
  final String uid;
  @override
  State<_AdminVerificationPanel> createState() =>
      _AdminVerificationPanelState();
}

class _AdminVerificationPanelState extends State<_AdminVerificationPanel> {
  final checks = <String>{};
  int? displayedRevision;
  bool busy = false;
  String? message;
  DateTime validUntil = DateTime.now().add(const Duration(days: 365));
  static const checklist = {
    'identity': 'NIC name and number match; both sides are readable',
    'face': 'Face photo matches the identity document',
    'capability': 'Service capability and towing documents checked',
    'contact': 'Contact and address details checked',
  };
  Future<void> act(Map<String, dynamic> application, String action) async {
    final reason = await _adminReason(
      context,
      action == 'verified'
          ? 'Approval reason (visible to provider)'
          : action == 'pending'
          ? 'Documents or corrections required'
          : 'Rejection reason',
    );
    if (reason == null || !mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await AdminService().moderate(
        widget.uid,
        verification: action,
        reason: reason,
        verificationRevision: action == 'verified'
            ? application['revision'] as int
            : null,
        validUntil: action == 'verified' ? validUntil : null,
        verificationChecks: action == 'verified' ? checks.toList() : null,
      );
      if (action == 'verified') {
        try {
          await AdminService().sendApprovalEmail(widget.uid);
          if (mounted)
            setState(
              () => message =
                  'Approved. Verification email accepted by the email service.',
            );
        } catch (_) {
          if (mounted)
            setState(
              () => message =
                  'Approval saved; email delivery failed. Deploy/configure the email endpoint, then use Retry approval email.',
            );
        }
      } else if (mounted) {
        setState(
          () => message = 'Decision saved. The provider can see it in the app.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Decision could not be saved. Check your permissions and application version.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('providerApplications')
        .doc(widget.uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Text(
          'Document access requires provider reviewer or super admin permission.',
        );
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final a = snapshot.data!.data();
      if (a == null)
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No verification application submitted. Ask this provider to sign in and submit their documents before approval.',
            ),
          ),
        );
      if (displayedRevision != a['revision']) {
        checks.clear();
        displayedRevision = a['revision'] as int;
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Private verification application',
                style: RaText.title,
              ),
              const Text(
                'Identity documents must stay inside this review. Do not copy them to public notes or reports.',
              ),
              for (final key in [
                'legalName',
                'nicNumber',
                'address',
                'businessName',
                'emergencyPhone',
                'experienceYears',
                'services',
                'vehicleTypes',
                'revision',
              ])
                SummaryRow(key, '${a[key] ?? ''}'),
              const Text(
                'Work experience and business capability',
                style: RaText.title,
              ),
              for (final e in (a['professionalDetails'] as Map? ?? {}).entries)
                SummaryRow(e.key.toString(), e.value.toString()),
              for (final e in (a['documents'] as Map).entries)
                ExpansionTile(
                  title: Text('${e.key}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _privateDocumentPreview(e.value as String, 280),
                    ),
                  ],
                ),
              const Text('Reviewer checklist', style: RaText.title),
              for (final e in checklist.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.value),
                  value: checks.contains(e.key),
                  onChanged: busy
                      ? null
                      : (yes) => setState(() {
                          if (yes == true) {
                            checks.add(e.key);
                          } else {
                            checks.remove(e.key);
                          }
                        }),
                ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: validUntil,
                          firstDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 366),
                          ),
                        );
                        if (date != null && mounted)
                          setState(() => validUntil = date);
                      },
                child: Text(
                  'Approval expiry: ${validUntil.toLocal().toString().split(' ').first}',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        busy ||
                            a['professionalDetails'] is! Map ||
                            checks.length != checklist.length
                        ? null
                        : () => act(a, 'verified'),
                    child: const Text('Approve verified provider'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => act(a, 'pending'),
                    child: const Text('Request corrections / renewal'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => act(a, 'rejected'),
                    child: const Text('Reject application'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              await AdminService().sendApprovalEmail(
                                widget.uid,
                              );
                              if (mounted)
                                setState(
                                  () => message =
                                      'Email accepted, or already sent for this approval.',
                                );
                            } catch (_) {
                              if (mounted)
                                setState(
                                  () => message =
                                      'Email unavailable. Approval remains unchanged.',
                                );
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: const Text('Retry approval email'),
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              if (message != null) Text(message!),
            ],
          ),
        ),
      );
    },
  );
}
