part of '../../screens.dart';

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

  Future<void> _act(Map<String, dynamic> application, String action) async {
    ProviderCorrectionDraft? correction;
    String? reason;
    if (action == 'pending') {
      final keys = <String>{
        'selfie',
        'nicFront',
        'nicBack',
        'serviceProof',
        ...(application['documents'] as Map? ?? {}).keys.whereType<String>(),
      }.where(ProviderDocumentCorrection.labels.containsKey).toList();
      correction = await showDialog<ProviderCorrectionDraft>(
        context: context,
        builder: (_) => ProviderCorrectionDialog(documentKeys: keys),
      );
      reason = correction?.reason;
    } else {
      reason = await _adminReason(
        context,
        action == 'verified'
            ? 'Approval reason (visible to provider)'
            : 'Rejection reason',
      );
    }

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });

    try {
      final revision = (application['revision'] as num?)?.toInt();

      if (action == 'verified' && revision == null) {
        throw StateError('Application revision missing');
      }

      await AdminService().moderate(
        widget.uid,
        verification: action,
        reason: reason,
        correctionDocuments: correction?.documents,
        expectedApplicationRevision: correction != null ? revision : null,
        verificationRevision: action == 'verified' ? revision : null,
        validUntil: action == 'verified' ? validUntil : null,
        verificationChecks: action == 'verified' ? checks.toList() : null,
      );

      if (action == 'verified') {
        try {
          await AdminService().sendApprovalEmail(widget.uid);

          if (!mounted) {
            return;
          }

          setState(() {
            message =
                'Provider approved. The approval email was accepted by the email service.';
          });
        } catch (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            message =
                'Provider approval was saved, but the approval email could not be delivered. You can retry the email below.';
          });
        }
      } else if (mounted) {
        setState(() {
          message =
              'Decision saved. The provider can see the updated verification result in the app.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        message = error is StateError
            ? error.message
            : 'Decision could not be saved. Check your admin permission and the current application revision.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _retryApprovalEmail() async {
    if (busy) {
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });

    try {
      await AdminService().sendApprovalEmail(widget.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        message =
            'Approval email accepted, or it was already sent for this approval.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        message =
            'Approval email is currently unavailable. Verification state was not changed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String _friendlyLabel(String value) {
    if (value == 'selfie') return 'Provider selfie — compare with NIC';
    if (value == 'customServices') return 'Additional services';
    const labels = {
      'legalName': 'Legal name',
      'nicNumber': 'NIC number',
      'address': 'Address',
      'businessName': 'Business name',
      'emergencyPhone': 'Emergency phone',
      'experienceYears': 'Experience',
      'services': 'Services',
      'vehicleTypes': 'Supported vehicles',
      'revision': 'Application revision',
      'providerType': 'Provider type',
      'available24Hours': '24-hour service',
      'businessPhone': 'Service phone',
      'businessRegistration': 'Business registration',
      'workHistory': 'Work history',
      'qualification': 'Qualification',
      'trainingInstitute': 'Training institute',
      'qualificationYear': 'Qualification year',
      'specializations': 'Specializations',
      'coverageAreas': 'Coverage areas',
      'radiusKm': 'Service radius',
      'startTime': 'Start time',
      'endTime': 'End time',
      'towRegistration': 'Recovery vehicle',
      'towCapacityKg': 'Recovery capacity',
      'insuranceDetails': 'Insurance / permits',
      'languages': 'Languages',
      'workDays': 'Working days',
      'tools': 'Tools / equipment',
    };

    return labels[value] ?? value.replaceAll('_', ' ').trim();
  }

  String _valueText(Object? value) {
    if (value == null) {
      return 'Not provided';
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is List) {
      if (value.isEmpty) {
        return 'Not provided';
      }

      return value.join(', ');
    }

    final text = value.toString().trim();

    return text.isEmpty ? 'Not provided' : text;
  }

  Future<void> _selectValidityDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: validUntil.isAfter(now)
          ? validUntil
          : now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 366)),
    );

    if (date == null || !mounted) {
      return;
    }

    setState(() {
      validUntil = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerApplications')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _RaAdminVerificationNotice(
            icon: Icons.lock_outline_rounded,
            title: 'Verification documents unavailable',
            message:
                'Document access requires provider reviewer or super-admin permission.',
            tone: raDanger,
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: LinearProgressIndicator(),
          );
        }

        final application = snapshot.data?.data();

        if (application == null) {
          return const _RaAdminVerificationNotice(
            icon: Icons.description_outlined,
            title: 'No application submitted',
            message:
                'Ask this provider to submit their verification documents before an approval decision can be made.',
            tone: raBlue,
          );
        }

        if (application['applicationStatus'] == 'withdrawn') {
          return const InlineMessage(
            icon: Icons.cancel_outlined,
            text:
                'Application withdrawn by the provider. Review is stopped. Saved documents remain private; the provider may apply again.',
          );
        }
        final revision = (application['revision'] as num?)?.toInt() ?? 0;

        if (displayedRevision != revision) {
          checks.clear();

          displayedRevision = revision;
        }

        final professional = application['professionalDetails'];

        final documents = application['documents'];

        final applicationFields = <String>[
          'legalName',
          'nicNumber',
          'address',
          'businessName',
          'emergencyPhone',
          'experienceYears',
          'services',
          'customServices',
          'vehicleTypes',
          'revision',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('accountModeration')
                  .doc(widget.uid)
                  .snapshots(),
              builder: (context, review) {
                final request = ProviderDocumentCorrection.active(
                  application,
                  review.data?.data(),
                );
                if (request == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InlineMessage(
                    icon: Icons.pending_actions,
                    text:
                        'Waiting for corrected documents: ${request.documents.map((key) => ProviderDocumentCorrection.labels[key]).join(', ')}. Approval is available after resubmission.',
                  ),
                );
              },
            ),
            _RaAdminVerificationHero(
              revision: revision,
              providerName: application['legalName']?.toString(),
            ),

            const SizedBox(height: 12),

            const _RaAdminVerificationNotice(
              icon: Icons.privacy_tip_outlined,
              title: 'Private review material',
              message:
                  'Identity documents are private. Do not copy document contents into public notes, reports or participant messages.',
              tone: raGold,
            ),

            const SizedBox(height: 20),

            const _RaAdminVerificationHeading(
              title: 'Application information',
              subtitle:
                  'Identity, service and vehicle information submitted by the provider.',
            ),

            const SizedBox(height: 10),

            _RaAdminVerificationSurface(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < applicationFields.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(height: 1),

                    _RaAdminVerificationRow(
                      label: _friendlyLabel(applicationFields[index]),
                      value: _valueText(application[applicationFields[index]]),
                    ),
                  ],
                ],
              ),
            ),

            if (professional is Map) ...[
              const SizedBox(height: 20),

              const _RaAdminVerificationHeading(
                title: 'Professional capability',
                subtitle:
                    'Experience, qualifications, coverage and equipment declared by the provider.',
              ),

              const SizedBox(height: 10),

              _RaAdminVerificationSurface(
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < professional.entries.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 1),

                      Builder(
                        builder: (context) {
                          final entry = professional.entries.elementAt(index);

                          return _RaAdminVerificationRow(
                            label: _friendlyLabel(entry.key.toString()),
                            value: _valueText(entry.value),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (documents is Map) ...[
              const SizedBox(height: 20),

              _RaAdminVerificationHeading(
                title: 'Submitted documents',
                subtitle:
                    '${documents.length} private ${documents.length == 1 ? 'document' : 'documents'} available for reviewer inspection.',
              ),

              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  final identity = [
                    _RaAdminVerificationDocument(
                      label: 'Provider selfie',
                      document: documents['selfie'],
                    ),
                    _RaAdminVerificationDocument(
                      label: 'NIC front — compare face',
                      document: documents['nicFront'],
                    ),
                  ];
                  if (constraints.maxWidth < 500)
                    return Column(
                      children: [
                        identity[0],
                        const SizedBox(height: 8),
                        identity[1],
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identity[0]),
                      const SizedBox(width: 12),
                      Expanded(child: identity[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              for (final entry in documents.entries) ...[
                _RaAdminVerificationDocument(
                  label: _friendlyLabel(entry.key.toString()),
                  document: entry.value,
                ),
                const SizedBox(height: 8),
              ],
            ],

            const SizedBox(height: 20),

            _RaAdminVerificationChecklistHeader(
              completed: checks.length,
              total: checklist.length,
            ),

            const SizedBox(height: 10),

            _RaAdminVerificationSurface(
              child: Column(
                children: [
                  for (final entry in checklist.entries)
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: checks.contains(entry.key),
                        onChanged: busy
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected == true) {
                                    checks.add(entry.key);
                                  } else {
                                    checks.remove(entry.key);
                                  }
                                });
                              },
                        title: Text(
                          entry.value,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: busy ? null : _selectValidityDate,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                'Valid until ${validUntil.day.toString().padLeft(2, '0')}/${validUntil.month.toString().padLeft(2, '0')}/${validUntil.year}',
              ),
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;

                final approve = FilledButton.icon(
                  onPressed:
                      busy ||
                          professional is! Map ||
                          checks.length != checklist.length
                      ? null
                      : () {
                          _act(application, 'verified');
                        },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Approve Provider'),
                );

                final corrections = OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          _act(application, 'pending');
                        },
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Request Corrections'),
                );

                final reject = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(
                      color: colors.error.withValues(alpha: .55),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () {
                          _act(application, 'rejected');
                        },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      approve,
                      const SizedBox(height: 8),
                      corrections,
                      const SizedBox(height: 8),
                      reject,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 2, child: approve),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: corrections),
                    const SizedBox(width: 8),
                    Expanded(child: reject),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : _retryApprovalEmail,
                icon: const Icon(Icons.forward_to_inbox_outlined),
                label: const Text('Retry Approval Email'),
              ),
            ),

            if (busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],

            if (message != null) ...[
              const SizedBox(height: 10),
              _RaAdminVerificationNotice(
                icon: Icons.info_outline_rounded,
                title: 'Review update',
                message: message!,
                tone: colors.primary,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RaAdminVerificationHero extends StatelessWidget {
  const _RaAdminVerificationHero({
    required this.revision,
    required this.providerName,
  });

  final int revision;
  final String? providerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _providerSurface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.onSurface,
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider verification',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),

                if (providerName != null &&
                    providerName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    providerName!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                Text(
                  'Review private identity and service-capability evidence before making a decision.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .72),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'REV $revision',
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAdminVerificationHeading extends StatelessWidget {
  const _RaAdminVerificationHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaAdminVerificationSurface extends StatelessWidget {
  const _RaAdminVerificationSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: child,
    );
  }
}

class _RaAdminVerificationNotice extends StatelessWidget {
  const _RaAdminVerificationNotice({
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
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
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

class _RaAdminVerificationChecklistHeader extends StatelessWidget {
  const _RaAdminVerificationChecklistHeader({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final progress = total == 0 ? 0.0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Reviewer checklist',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$completed/$total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 5),
        ),
      ],
    );
  }
}

class _RaAdminVerificationDocument extends StatelessWidget {
  const _RaAdminVerificationDocument({
    required this.label,
    required this.document,
  });

  final String label;
  final Object? document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          leading: Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: colors.primary,
              size: 19,
            ),
          ),
          title: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Private verification evidence',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child:
                  document is String && (document as String).trim().isNotEmpty
                  ? _privateDocumentPreview(document as String, 280)
                  : const _RaAdminVerificationNotice(
                      icon: Icons.broken_image_outlined,
                      title: 'Document unavailable',
                      message:
                          'The stored verification document could not be displayed.',
                      tone: raDanger,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaAdminVerificationRow extends StatelessWidget {
  const _RaAdminVerificationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 175,
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
