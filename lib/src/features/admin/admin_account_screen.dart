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

  late final user =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots();

  late final moderation =
      FirebaseFirestore.instance
          .collection('accountModeration')
          .doc(widget.uid)
          .snapshots();

  Future<void> change(
    String action,
  ) async {
    final reason =
        await _adminReason(
      context,
      '$action account',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService().moderate(
        widget.uid,
        reason: reason,
        verification:
            action == 'Verify'
                ? 'verified'
                : action == 'Reject'
                    ? 'rejected'
                    : null,
        status:
            action == 'Suspend'
                ? 'suspended'
                : action == 'Restore'
                    ? 'active'
                    : null,
        flagged:
            action == 'Flag'
                ? true
                : action == 'Clear flag'
                    ? false
                    : null,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
    final reason =
        await _adminReason(
      context,
      'Deletion reason',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    final confirmation =
        await _adminReason(
      context,
      'Confirm permanent deletion',
      expectedId: widget.uid,
    );

    if (confirmation != widget.uid ||
        !mounted) {
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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

  String titleCase(
    String value,
  ) {
    if (value.trim().isEmpty) {
      return 'Unknown';
    }

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where(
          (part) => part.isNotEmpty,
        )
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Account Review',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: user,
        builder: (
          context,
          snapshot,
        ) {
          return StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
            stream: moderation,
            builder: (
              context,
              review,
            ) {
              if (snapshot.hasError ||
                  review.hasError) {
                return const Padding(
                  padding:
                      EdgeInsets.all(20),
                  child: EmptyState(
                    icon:
                        Icons.cloud_off_outlined,
                    title:
                        'Could not load account',
                    message:
                        'Check current administrator permission and connection.',
                  ),
                );
              }

              if (!snapshot.hasData ||
                  !review.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final data =
                  snapshot.data!.data();

              if (data == null) {
                return const Padding(
                  padding:
                      EdgeInsets.all(20),
                  child: EmptyState(
                    icon:
                        Icons.person_off_outlined,
                    title:
                        'Profile no longer exists',
                    message:
                        'The user profile document is unavailable.',
                  ),
                );
              }

              final decision =
                  review.data!.data() ??
                      {};

              final own =
                  FirebaseAuth.instance
                          .currentUser
                          ?.uid ==
                      widget.uid;

              final name =
                  data['displayName']
                          as String? ??
                      widget.uid;

              final email =
                  data['email']
                          as String? ??
                      '';

              final phone =
                  data['phone']
                          as String? ??
                      '';

              final role =
                  data['role']
                          as String? ??
                      '';

              final accessStatus =
                  decision['status']
                          as String? ??
                      'active';

              final verification =
                  decision['verification']
                          as String? ??
                      'pending';

              final flagged =
                  decision['flagged'] ==
                      true;

              final reason =
                  decision['reason']
                          ?.toString() ??
                      '';

              final services =
                  (data['services']
                              as List<dynamic>? ??
                          const [])
                      .map(
                        (value) =>
                            value.toString(),
                      )
                      .where(
                        (value) =>
                            value
                                .trim()
                                .isNotEmpty,
                      )
                      .toList();

              return ListView(
                physics:
                    const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  32,
                ),
                children: [
                  _AdminAccountHero(
                    uid:
                        widget.uid,
                    name:
                        name,
                    email:
                        email,
                    role:
                        role,
                    accessStatus:
                        accessStatus,
                    flagged:
                        flagged,
                  ),

                  const SizedBox(height: 23),

                  const _AdminAccountHeading(
                    title:
                        'Account information',
                    subtitle:
                        'Current profile and moderation state.',
                  ),

                  const SizedBox(height: 10),

                  _AdminAccountSurface(
                    child: Column(
                      children: [
                        _AdminAccountRow(
                          label: 'Email',
                          value: email.isEmpty
                              ? 'Not provided'
                              : email,
                        ),
                        const Divider(
                          height: 1,
                        ),
                        _AdminAccountRow(
                          label: 'Phone',
                          value: phone.isEmpty
                              ? 'Not provided'
                              : phone,
                        ),
                        const Divider(
                          height: 1,
                        ),
                        _AdminAccountRow(
                          label: 'Role',
                          value:
                              titleCase(role),
                        ),
                        const Divider(
                          height: 1,
                        ),
                        _AdminAccountRow(
                          label: 'Access',
                          value: titleCase(
                            accessStatus,
                          ),
                        ),
                        const Divider(
                          height: 1,
                        ),
                        _AdminAccountRow(
                          label:
                              'Verification',
                          value: titleCase(
                            verification,
                          ),
                        ),
                        const Divider(
                          height: 1,
                        ),
                        _AdminAccountRow(
                          label: 'Flagged',
                          value: flagged
                              ? 'Yes'
                              : 'No',
                        ),
                      ],
                    ),
                  ),

                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),

                    _AdminAccountNotice(
                      icon:
                          Icons.history_outlined,
                      title:
                          'Last moderation reason',
                      message:
                          reason,
                      tone:
                          Theme.of(context)
                              .colorScheme
                              .primary,
                    ),
                  ],

                  const SizedBox(height: 23),

                  const _AdminAccountHeading(
                    title:
                        'Administrative actions',
                    subtitle:
                        'All moderation changes require a reason and remain subject to the existing AdminService permission checks.',
                  ),

                  const SizedBox(height: 10),

                  _AdminAccountSurface(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const _AdminAccountNotice(
                          icon: Icons
                              .info_outline_rounded,
                          title:
                              'Access moderation',
                          message:
                              'Suspension blocks application database operations but does not disable Firebase Authentication. Check active work before suspending an account.',
                          tone:
                              raGold,
                        ),

                        const SizedBox(height: 14),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  busy ||
                                          own ||
                                          accessStatus ==
                                              'suspended'
                                      ? null
                                      : () {
                                          change(
                                            'Suspend',
                                          );
                                        },
                              icon: const Icon(
                                Icons
                                    .block_outlined,
                              ),
                              label:
                                  const Text(
                                'Suspend',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  busy ||
                                          accessStatus ==
                                              'active'
                                      ? null
                                      : () {
                                          change(
                                            'Restore',
                                          );
                                        },
                              icon: const Icon(
                                Icons
                                    .restore_rounded,
                              ),
                              label:
                                  const Text(
                                'Restore',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  busy ||
                                          flagged
                                      ? null
                                      : () {
                                          change(
                                            'Flag',
                                          );
                                        },
                              icon: const Icon(
                                Icons
                                    .flag_outlined,
                              ),
                              label:
                                  const Text(
                                'Flag',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  busy ||
                                          !flagged
                                      ? null
                                      : () {
                                          change(
                                            'Clear flag',
                                          );
                                        },
                              icon: const Icon(
                                Icons
                                    .outlined_flag,
                              ),
                              label:
                                  const Text(
                                'Clear Flag',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (role ==
                      'provider') ...[
                    const SizedBox(height: 25),

                    const _AdminAccountHeading(
                      title:
                          'Provider information',
                      subtitle:
                          'Review registered services and private verification material.',
                    ),

                    const SizedBox(height: 10),

                    _AdminAccountSurface(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'SERVICES',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 7.3,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing:
                                  .65,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            services.isEmpty
                                ? 'No services recorded.'
                                : services.join(
                                    ', ',
                                  ),
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 9.3,
                              height: 1.45,
                            ),
                          ),

                          if (data['photoData']
                                  is String &&
                              (data['photoData']
                                      as String)
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(
                              height: 14,
                            ),

                            RevisionEvidencePhotos(
                              photos: [
                                data['photoData']
                                    as String,
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          Text(
                            'Private provider approval should be completed using the verification application and reviewer checklist below.',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 8.2,
                              height: 1.4,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _AdminVerificationPanel(
                      uid: widget.uid,
                    ),
                  ],

                  const SizedBox(height: 25),

                  _AdminUserActivity(
                    uid: widget.uid,
                  ),

                  const SizedBox(height: 25),

                  StreamBuilder<
                      DocumentSnapshot<
                          Map<String, dynamic>>>(
                    stream: FirebaseFirestore
                        .instance
                        .collection(
                          'adminAccess',
                        )
                        .doc(
                          FirebaseAuth
                              .instance
                              .currentUser!
                              .uid,
                        )
                        .snapshots(),
                    builder: (
                      context,
                      access,
                    ) {
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

                      return _AdminAccountDangerZone(
                        busy:
                            busy,
                        own:
                            own,
                        onDelete:
                            deleteAccount,
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  _AdminPrivateNotes(
                    kind: 'account',
                    target: widget.uid,
                  ),

                  if (busy) ...[
                    const SizedBox(height: 15),
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

class _AdminAccountHero extends StatelessWidget {
  const _AdminAccountHero({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.accessStatus,
    required this.flagged,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String accessStatus;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF075A68),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          ProfileInitials(
            name: name,
            radius: 29,
          ),
          const SizedBox(width: 12),
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
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email.trim().isEmpty
                      ? uid
                      : email,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 8.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _AdminStatusBadge(
                      status: role.isEmpty
                          ? 'account'
                          : role,
                    ),
                    _AdminStatusBadge(
                      status:
                          accessStatus,
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
    );
  }
}

class _AdminAccountHeading extends StatelessWidget {
  const _AdminAccountHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AdminAccountSurface extends StatelessWidget {
  const _AdminAccountSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: child,
    );
  }
}

class _AdminAccountRow extends StatelessWidget {
  const _AdminAccountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8.1,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountNotice extends StatelessWidget {
  const _AdminAccountNotice({
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
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: tone.withValues(alpha: .17),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: tone,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.3,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.1,
                    height: 1.45,
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

class _AdminAccountDangerZone extends StatelessWidget {
  const _AdminAccountDangerZone({
    required this.busy,
    required this.own,
    required this.onDelete,
  });

  final bool busy;
  final bool own;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            colors.error.withValues(alpha: .055),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              colors.error.withValues(alpha: .20),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permanent account deletion',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w800,
                    color: colors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Login, profile, vehicles, device tokens and verification documents are removed. Job, payment, complaint and audit records remain. Active jobs, unconfirmed payments and unresolved complaints block deletion.',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 8.2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed:
                busy || own ? null : onDelete,
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  colors.error,
              side: BorderSide(
                color: colors.error
                    .withValues(alpha: .45),
              ),
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
  }
}