part of '../../screens.dart';

class _AdminAccountScreen extends StatefulWidget {
  const _AdminAccountScreen({
    required this.uid,
  });

  final String uid;

  @override
  State<_AdminAccountScreen> createState() =>
      _AdminAccountScreenState();
}

class _AdminAccountScreenState
    extends State<_AdminAccountScreen> {
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
    final reason = await _adminReason(
      context,
      '$action account',
    );

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Action failed. Check admin permission and connection.',
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

  Future<void> deleteAccount() async {
    final reason = await _adminReason(
      context,
      'Deletion reason',
    );

    if (reason == null || !mounted) {
      return;
    }

    final confirmation = await _adminReason(
      context,
      'Confirm permanent deletion',
      expectedId: widget.uid,
    );

    if (confirmation != widget.uid || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService().deleteAccount(
        widget.uid,
        reason,
        confirmation!,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Review'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: user,
        builder: (context, snapshot) {
          return StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            stream: moderation,
            builder: (context, review) {
              if (snapshot.hasError || review.hasError) {
                return const Center(
                  child: Text(
                    'Could not load account.',
                  ),
                );
              }

              if (!snapshot.hasData || !review.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final data = snapshot.data!.data();

              if (data == null) {
                return const Center(
                  child: Text(
                    'Profile no longer exists.',
                  ),
                );
              }

              final decision =
                  review.data!.data() ?? {};

              final own =
                  FirebaseAuth.instance.currentUser?.uid ==
                      widget.uid;

              final name =
                  data['displayName'] as String? ??
                      widget.uid;

              final email =
                  data['email'] as String? ?? '';

              final phone =
                  data['phone'] as String? ?? '';

              final role =
                  data['role'] as String? ?? '';

              final accessStatus =
                  decision['status'] as String? ??
                      'active';

              final verification =
                  decision['verification'] as String? ??
                      'pending';

              final flagged =
                  decision['flagged'] == true;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.lg,
                  RaSpace.md,
                  RaSpace.lg,
                  RaSpace.xxxl,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(
                      RaSpace.xl,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary,
                          const Color(0xFF007D70),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        ProfileInitials(
                          name: name,
                          radius: 32,
                        ),
                        const SizedBox(
                          width: RaSpace.lg,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: theme
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email.isEmpty
                                    ? widget.uid
                                    : email,
                                style: theme
                                    .textTheme.bodySmall
                                    ?.copyWith(
                                  color: Colors.white
                                      .withValues(
                                    alpha: .82,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: RaSpace.sm,
                              ),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _AdminStatusBadge(
                                    status: role.isEmpty
                                        ? 'account'
                                        : role,
                                  ),
                                  _AdminStatusBadge(
                                    status: accessStatus,
                                  ),
                                  if (flagged)
                                    const _AdminStatusBadge(
                                      status: 'flagged',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RaSpace.xl),

                  Text(
                    'Account information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  Container(
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
                      children: [
                        SummaryRow(
                          'Email',
                          email.isEmpty
                              ? 'Not provided'
                              : email,
                        ),
                        SummaryRow(
                          'Phone',
                          phone.isEmpty
                              ? 'Not provided'
                              : phone,
                        ),
                        SummaryRow(
                          'Role',
                          role.isEmpty
                              ? 'Unknown'
                              : role,
                        ),
                        SummaryRow(
                          'Access',
                          accessStatus,
                        ),
                        SummaryRow(
                          'Verification',
                          verification,
                        ),
                        SummaryRow(
                          'Flagged',
                          flagged ? 'Yes' : 'No',
                        ),
                      ],
                    ),
                  ),

                  if (decision['reason'] != null) ...[
                    const SizedBox(height: RaSpace.md),
                    Container(
                      padding: const EdgeInsets.all(
                        RaSpace.md,
                      ),
                      decoration: BoxDecoration(
                        color: colors
                            .surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 19,
                            color: colors.primary,
                          ),
                          const SizedBox(
                            width: RaSpace.sm,
                          ),
                          Expanded(
                            child: Text(
                              'Last moderation reason: ${decision['reason']}',
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: RaSpace.xl),

                  Text(
                    'Administrative actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: RaSpace.sm),

                  Text(
                    'Suspension blocks application database operations but does not disable Firebase authentication. Check active work before suspending an account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  Wrap(
                    spacing: RaSpace.sm,
                    runSpacing: RaSpace.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy || own
                            ? null
                            : () => change('Suspend'),
                        icon: const Icon(
                          Icons.block_outlined,
                        ),
                        label: const Text('Suspend'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => change('Restore'),
                        icon: const Icon(
                          Icons.restore_rounded,
                        ),
                        label: const Text('Restore'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => change('Flag'),
                        icon: const Icon(
                          Icons.flag_outlined,
                        ),
                        label: const Text('Flag'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => change('Clear flag'),
                        icon: const Icon(
                          Icons.outlined_flag,
                        ),
                        label: const Text('Clear Flag'),
                      ),
                    ],
                  ),

                  if (role == 'provider') ...[
                    const SizedBox(height: RaSpace.xxl),

                    Text(
                      'Provider information',
                      style: theme
                          .textTheme.titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    Container(
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
                          Text(
                            'Services',
                            style: theme
                                .textTheme.titleSmall
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (data['services'] as List? ??
                                    [])
                                .join(', ')
                                .trim()
                                .isEmpty
                                ? 'No services recorded.'
                                : (data['services']
                                            as List? ??
                                        [])
                                    .join(', '),
                            style: theme
                                .textTheme.bodyMedium,
                          ),
                          if (data['photoData']
                                  is String &&
                              (data['photoData'] as String)
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(
                              height: RaSpace.md,
                            ),
                            RevisionEvidencePhotos(
                              photos: [
                                data['photoData']
                                    as String,
                              ],
                            ),
                          ],
                          const SizedBox(
                            height: RaSpace.sm,
                          ),
                          Text(
                            'Review the private provider application and checklist before approval.',
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

                    const SizedBox(height: RaSpace.md),

                    _AdminVerificationPanel(
                      uid: widget.uid,
                    ),
                  ],

                  const SizedBox(height: RaSpace.xxl),

                  _AdminUserActivity(
                    uid: widget.uid,
                  ),

                  const SizedBox(height: RaSpace.xxl),

                  StreamBuilder<
                      DocumentSnapshot<
                          Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('adminAccess')
                        .doc(
                          FirebaseAuth.instance
                              .currentUser!.uid,
                        )
                        .snapshots(),
                    builder: (context, access) {
                      final adminRole =
                          access.data
                                  ?.data()?['role'] ??
                              '';

                      if (!access.hasData ||
                          adminRole !=
                              'super_admin') {
                        return const SizedBox
                            .shrink();
                      }

                      return Container(
                        padding: const EdgeInsets.all(
                          RaSpace.lg,
                        ),
                        decoration: BoxDecoration(
                          color: colors.errorContainer
                              .withValues(alpha: .24),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.error
                                .withValues(alpha: .22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: colors.error,
                                ),
                                const SizedBox(
                                  width: RaSpace.sm,
                                ),
                                Expanded(
                                  child: Text(
                                    'Permanent account deletion',
                                    style: theme
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.w900,
                                      color:
                                          colors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: RaSpace.sm,
                            ),
                            Text(
                              'Login, profile, vehicles, device tokens and verification documents are removed. Job, payment, complaint and audit records remain. Active jobs, unconfirmed payments and unresolved complaints block deletion.',
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(
                              height: RaSpace.md,
                            ),
                            OutlinedButton.icon(
                              onPressed: busy || own
                                  ? null
                                  : deleteAccount,
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor:
                                    colors.error,
                              ),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                              ),
                              label: const Text(
                                'Delete Account Permanently',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: RaSpace.xxl),

                  _AdminPrivateNotes(
                    kind: 'account',
                    target: widget.uid,
                  ),

                  if (busy) ...[
                    const SizedBox(height: RaSpace.lg),
                    const LinearProgressIndicator(),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}