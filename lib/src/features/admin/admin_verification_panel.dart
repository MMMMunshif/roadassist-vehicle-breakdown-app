part of '../../screens.dart';

class _AdminVerificationPanel
    extends StatefulWidget {
  const _AdminVerificationPanel({
    required this.uid,
  });

  final String uid;

  @override
  State<_AdminVerificationPanel>
      createState() =>
          _AdminVerificationPanelState();
}

class _AdminVerificationPanelState
    extends State<_AdminVerificationPanel> {
  final checks = <String>{};

  int? displayedRevision;

  bool busy = false;

  String? message;

  DateTime validUntil =
      DateTime.now().add(
    const Duration(days: 365),
  );

  static const checklist = {
    'identity':
        'NIC name and number match; both sides are readable',
    'face':
        'Face photo matches the identity document',
    'capability':
        'Service capability and towing documents checked',
    'contact':
        'Contact and address details checked',
  };

  Future<void> act(
    Map<String, dynamic> application,
    String action,
  ) async {
    final reason =
        await _adminReason(
      context,
      action == 'verified'
          ? 'Approval reason (visible to provider)'
          : action == 'pending'
          ? 'Documents or corrections required'
          : 'Rejection reason',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });

    try {
      await AdminService().moderate(
        widget.uid,
        verification: action,
        reason: reason,
        verificationRevision:
            action == 'verified'
            ? application['revision']
                  as int
            : null,
        validUntil:
            action == 'verified'
            ? validUntil
            : null,
        verificationChecks:
            action == 'verified'
            ? checks.toList()
            : null,
      );

      if (action == 'verified') {
        try {
          await AdminService()
              .sendApprovalEmail(
            widget.uid,
          );

          if (mounted) {
            setState(() {
              message =
                  'Approved. Verification email accepted by the email service.';
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              message =
                  'Approval saved; email delivery failed. Retry the approval email after checking the email service.';
            });
          }
        }
      } else if (mounted) {
        setState(() {
          message =
              'Decision saved. The provider can see the result in the app.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message =
              'Decision could not be saved. Check permissions and application revision.';
        });
      }
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

    return StreamBuilder<
      DocumentSnapshot<
        Map<String, dynamic>
      >
    >(
      stream: FirebaseFirestore.instance
          .collection(
            'providerApplications',
          )
          .doc(widget.uid)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.lock_outline,
            text:
                'Document access requires provider reviewer or super-admin permission.',
            error: true,
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final application =
            snapshot.data!.data();

        if (application == null) {
          return Container(
            padding:
                const EdgeInsets.all(
              RaSpace.lg,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              border: Border.all(
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .6,
                ),
              ),
            ),
            child: const InlineMessage(
              icon: Icons
                  .description_outlined,
              text:
                  'No verification application has been submitted. Ask this provider to submit their documents before approval.',
            ),
          );
        }

        final revision =
            application['revision']
                as int;

        if (displayedRevision !=
            revision) {
          checks.clear();
          displayedRevision =
              revision;
        }

        final professional =
            application[
                'professionalDetails'];

        final documents =
            application['documents'];

        return Container(
          padding: const EdgeInsets.all(
            RaSpace.xl,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: colors.outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(15),
                    ),
                    child: Icon(
                      Icons
                          .verified_user_outlined,
                      color: colors
                          .onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(
                    width: RaSpace.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Private verification application',
                          style: theme
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Revision $revision',
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  RaSpace.md,
                ),
                decoration:
                    BoxDecoration(
                  color: raGoldPale,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .privacy_tip_outlined,
                      color: raGold,
                    ),
                    SizedBox(
                      width: RaSpace.sm,
                    ),
                    Expanded(
                      child: Text(
                        'Identity documents are private review material. Do not copy document content into public notes, reports or participant messages.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.xl,
              ),

              Text(
                'Application information',
                style: theme
                    .textTheme.titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
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
                _AdminVerificationRow(
                  label: key,
                  value:
                      '${application[key] ?? ''}',
                ),

              if (professional is Map) ...[
                const SizedBox(
                  height: RaSpace.xl,
                ),
                Text(
                  'Work experience & capability',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: RaSpace.sm,
                ),
                for (final entry
                    in professional.entries)
                  _AdminVerificationRow(
                    label:
                        entry.key.toString(),
                    value:
                        entry.value.toString(),
                  ),
              ],

              if (documents is Map) ...[
                const SizedBox(
                  height: RaSpace.xl,
                ),
                Text(
                  'Submitted documents',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: RaSpace.sm,
                ),
                for (final entry
                    in documents.entries)
                  Container(
                    margin:
                        const EdgeInsets.only(
                      bottom: RaSpace.sm,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .surfaceContainerHighest
                          .withValues(
                        alpha: .32,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(16),
                    ),
                    child: ExpansionTile(
                      leading: const Icon(
                        Icons
                            .description_outlined,
                      ),
                      title: Text(
                        '${entry.key}',
                      ),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.all(
                            RaSpace.md,
                          ),
                          child:
                              _privateDocumentPreview(
                            entry.value
                                as String,
                            280,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(
                height: RaSpace.xl,
              ),

              Text(
                'Reviewer checklist',
                style: theme
                    .textTheme.titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                '${checks.length}/${checklist.length} checks completed',
                style:
                    theme.textTheme.bodySmall,
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              for (final entry
                  in checklist.entries)
                CheckboxListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  controlAffinity:
                      ListTileControlAffinity
                          .leading,
                  title: Text(
                    entry.value,
                  ),
                  value: checks.contains(
                    entry.key,
                  ),
                  onChanged: busy
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected ==
                                true) {
                              checks.add(
                                entry.key,
                              );
                            } else {
                              checks.remove(
                                entry.key,
                              );
                            }
                          });
                        },
                ),

              const SizedBox(
                height: RaSpace.md,
              ),

              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final date =
                            await showDatePicker(
                          context: context,
                          initialDate:
                              validUntil,
                          firstDate:
                              DateTime.now()
                                  .add(
                            const Duration(
                              days: 1,
                            ),
                          ),
                          lastDate:
                              DateTime.now()
                                  .add(
                            const Duration(
                              days: 366,
                            ),
                          ),
                        );

                        if (date !=
                                null &&
                            mounted) {
                          setState(() {
                            validUntil =
                                date;
                          });
                        }
                      },
                icon: const Icon(
                  Icons
                      .event_available_outlined,
                ),
                label: Text(
                  'Verification valid until ${validUntil.toLocal().toString().split(' ').first}',
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              Wrap(
                spacing: RaSpace.sm,
                runSpacing: RaSpace.sm,
                children: [
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            professional
                                is! Map ||
                            checks.length !=
                                checklist.length
                        ? null
                        : () => act(
                            application,
                            'verified',
                          ),
                    icon: const Icon(
                      Icons
                          .verified_outlined,
                    ),
                    label: const Text(
                      'Approve Provider',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => act(
                            application,
                            'pending',
                          ),
                    icon: const Icon(
                      Icons
                          .edit_note_outlined,
                    ),
                    label: const Text(
                      'Request Corrections',
                    ),
                  ),
                  OutlinedButton.icon(
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          colors.error,
                    ),
                    onPressed: busy
                        ? null
                        : () => act(
                            application,
                            'rejected',
                          ),
                    icon: const Icon(
                      Icons
                          .cancel_outlined,
                    ),
                    label: const Text(
                      'Reject',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                            });

                            try {
                              await AdminService()
                                  .sendApprovalEmail(
                                widget.uid,
                              );

                              if (mounted) {
                                setState(() {
                                  message =
                                      'Approval email accepted, or already sent for this approval.';
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() {
                                  message =
                                      'Email unavailable. Verification state remains unchanged.';
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  busy =
                                      false;
                                });
                              }
                            }
                          },
                    icon: const Icon(
                      Icons
                          .forward_to_inbox_outlined,
                    ),
                    label: const Text(
                      'Retry Approval Email',
                    ),
                  ),
                ],
              ),

              if (busy) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                const LinearProgressIndicator(),
              ],

              if (message != null) ...[
                const SizedBox(
                  height: RaSpace.md,
                ),
                InlineMessage(
                  text: message!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdminVerificationRow
    extends StatelessWidget {
  const _AdminVerificationRow({
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
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label
                  .replaceAll('_', ' '),
              style: Theme.of(context)
                  .textTheme.bodySmall
                  ?.copyWith(
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme.bodyMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}