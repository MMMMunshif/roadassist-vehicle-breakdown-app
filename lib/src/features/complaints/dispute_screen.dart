part of '../../screens.dart';

class DisputeScreen extends StatefulWidget {
  const DisputeScreen({
    super.key,
    required this.requestId,
    this.sameProblem = false,
  });

  final bool sameProblem;
  final String requestId;

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final description = TextEditingController();

  final response = TextEditingController();

  final photos = <String>[];

  String reason = 'extra_charge';
  String responseType = 'review';

  bool busy = false;
  bool canReport = false;

  late final job = FirebaseFirestore.instance
      .collection('requests')
      .doc(widget.requestId);

  late final caseRef = job.collection('disputes').doc('case');

  late final caseStream = caseRef.snapshots();

  static const reasons = {
    'same_problem': 'Same problem again / Warranty review',
    'extra_charge': 'Extra money requested',
    'repair_quality': 'Repair problem',
    'incomplete_service': 'Service incomplete',
    'other': 'Other problem',
  };

  @override
  void initState() {
    super.initState();

    if (widget.sameProblem) {
      reason = 'same_problem';
    }

    unawaited(
      job
          .get()
          .then((snapshot) {
            if (!mounted) return;

            final data = snapshot.data();

            setState(() {
              canReport =
                  data?['driverId'] == FirebaseAuth.instance.currentUser?.uid &&
                  (data?['status'] == 'completed' ||
                      data?['completionState'] == 'pending');
            });
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    description.dispose();
    response.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      await action();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save this report. Check your connection and try again.',
          ),
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

  Future<void> addPhoto() async {
    if (busy || photos.length >= 2) {
      return;
    }

    await perform(() async {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (photo == null) return;

      final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);

      if (!mounted) return;

      setState(() {
        photos.add(encoded);
      });
    });
  }

  Future<void> submit() async {
    if (reason == 'same_problem' && photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a photo showing the repeated problem.'),
        ),
      );

      return;
    }

    if (description.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe the problem in at least 10 characters.'),
        ),
      );

      return;
    }

    await perform(() async {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final request = (await transaction.get(job)).data();

        final existing = await transaction.get(caseRef);

        if (existing.exists ||
            request == null ||
            (request['status'] != 'completed' &&
                request['completionState'] != 'pending') ||
            request['driverId'] != FirebaseAuth.instance.currentUser?.uid) {
          throw StateError('Unavailable');
        }

        transaction.set(caseRef, {
          'driverId': request['driverId'],
          'providerId': request['providerId'],
          'reason': reason,
          'description': description.text.trim(),
          'photos': List<String>.from(photos),
          'status': 'open',
          'providerResponse': '',
          'resolution': '',
          'approvedTotal': request['estimatedCost'] ?? 0,
          'finalTotal': request['finalCost'] ?? request['estimatedCost'] ?? 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  Future<void> reply() async {
    if (response.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a response of at least 10 characters.'),
        ),
      );

      return;
    }

    final prefix = switch (responseType) {
      'free_recheck' => 'Free recheck offered',
      'not_covered' => 'Coverage declined',
      _ => 'Review response',
    };

    await perform(
      () => caseRef.update({
        'providerResponse': '$prefix: ${response.text.trim()}',
        'status': 'under_review',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> resolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: raSuccess.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: raSuccess,
              size: 28,
            ),
          ),
          title: const Text('Problem resolved?'),
          content: const Text(
            'Confirm only when you are satisfied with the resolution. This does not automatically change the invoice or create a refund.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Not Yet'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm Resolved'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await perform(
      () => caseRef.update({
        'status': 'resolved',
        'resolution': 'Driver confirmed the problem is resolved.',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Color statusColor(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;

    return switch (status) {
      'resolved' => raSuccess,
      'under_review' => raGold,
      _ => colors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RaScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.sameProblem ? 'Warranty Review' : 'Service Problem',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: caseStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load report',
                message: 'Check your connection and try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!.data();

          final uid = FirebaseAuth.instance.currentUser?.uid;

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
            children: [
              _RaDisputeHero(
                existing: report != null,
                sameProblem: widget.sameProblem,
                status: report?['status'] as String?,
              ),

              const SizedBox(height: 25),

              if (report == null)
                if (canReport)
                  _buildReportForm(context)
                else
                  const EmptyState(
                    icon: Icons.report_problem_outlined,
                    title: 'Report unavailable',
                    message:
                        'Only the driver can open a service problem report after the job has been completed.',
                  )
              else
                _buildExistingReport(context, report, uid),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RaDisputeHeading(
          title: 'What went wrong?',
          subtitle: 'Explain the issue clearly so the provider can review it.',
        ),

        const SizedBox(height: 11),

        _RaDisputeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(
                  labelText: 'Problem type',
                  prefixIcon: Icon(Icons.report_problem_outlined),
                ),
                items: reasons.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          reason = value;
                        });
                      },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: description,
                enabled: !busy,
                maxLength: 1000,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Describe what happened',
                  hintText:
                      'Explain the problem and what you expected to happen.',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photo evidence',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${photos.length}/2',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              if (photos.isNotEmpty) ...[
                RevisionEvidencePhotos(photos: photos),

                const SizedBox(height: 7),

                Wrap(
                  spacing: 5,
                  children: [
                    for (var index = 0; index < photos.length; index++)
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() {
                                  photos.removeAt(index);
                                });
                              },
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: Text('Remove ${index + 1}'),
                      ),
                  ],
                ),
              ],

              OutlinedButton.icon(
                onPressed: busy || photos.length >= 2 ? null : addPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Evidence Photo'),
              ),

              if (reason == 'same_problem') ...[
                const SizedBox(height: 9),

                Text(
                  'A photo is required for a repeated-problem / warranty review.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: raGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 17),

              FilledButton.icon(
                onPressed: busy ? null : submit,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExistingReport(
    BuildContext context,
    Map<String, dynamic> report,
    String? uid,
  ) {
    final colors = Theme.of(context).colorScheme;

    final reportStatus = report['status'] as String? ?? 'open';

    final tone = statusColor(context, reportStatus);

    final isDriver = uid == report['driverId'];

    final isProvider = uid == report['providerId'];

    final providerResponse = report['providerResponse'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComplaintProgressPanel(requestId: widget.requestId),
        const SizedBox(height: 16),
        _RaDisputeStatusCard(
          status: reportStatus,
          reason: reasons[report['reason']] ?? 'Other problem',
          tone: tone,
        ),

        const SizedBox(height: 13),

        _RaDisputeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RaDisputeMiniHeading(
                icon: Icons.person_outline,
                title: 'Driver report',
              ),

              const SizedBox(height: 10),

              Text(
                report['description'] as String? ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  height: 1.5,
                  color: colors.onSurface,
                ),
              ),

              if ((report['photos'] as List? ?? []).isNotEmpty) ...[
                const SizedBox(height: 13),
                RevisionEvidencePhotos(
                  photos: List<String>.from(report['photos'] as List? ?? []),
                ),
              ],

              const SizedBox(height: 15),

              Divider(color: colors.outlineVariant),

              const SizedBox(height: 7),

              _RaDisputeMoneyRow(
                label: 'Approved total when reported',
                value: 'Rs. ${report['approvedTotal'] ?? 0}',
              ),

              _RaDisputeMoneyRow(
                label: 'Final recorded total',
                value: 'Rs. ${report['finalTotal'] ?? 0}',
                strong: true,
              ),
            ],
          ),
        ),

        if (providerResponse.trim().isNotEmpty) ...[
          const SizedBox(height: 13),

          _RaDisputeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _RaDisputeMiniHeading(
                  icon: Icons.handshake_outlined,
                  title: 'Provider response',
                ),
                const SizedBox(height: 10),
                Text(
                  providerResponse,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (reportStatus != 'resolved' && isProvider) ...[
          const SizedBox(height: 25),

          const _RaDisputeHeading(
            title: 'Respond to report',
            subtitle: 'Explain how you propose to handle the reported problem.',
          ),

          const SizedBox(height: 11),

          _RaDisputeCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: responseType,
                  decoration: const InputDecoration(
                    labelText: 'Proposed resolution',
                    prefixIcon: Icon(Icons.handshake_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'review',
                      child: Text('Review / discuss'),
                    ),
                    DropdownMenuItem(
                      value: 'free_recheck',
                      child: Text('Offer free recheck'),
                    ),
                    DropdownMenuItem(
                      value: 'not_covered',
                      child: Text('Not covered - explain why'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            responseType = value;
                          });
                        },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: response,
                  enabled: !busy,
                  maxLength: 900,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Response / proposed resolution',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: .38,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Do not add charges to the completed invoice. Any paid follow-up requires a separate request and driver-approved quote.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : reply,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send Response'),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (reportStatus == 'under_review' && isDriver) ...[
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : resolve,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Confirm Problem Resolved'),
            ),
          ),
        ],

        if (reportStatus == 'resolved') ...[
          const SizedBox(height: 13),

          _RaDisputeCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_outlined, color: raSuccess),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report['resolution'] as String? ??
                        'The driver confirmed that this report was resolved.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RaDisputeHero extends StatelessWidget {
  const _RaDisputeHero({
    required this.existing,
    required this.sameProblem,
    this.status,
  });

  final bool existing;
  final bool sameProblem;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final tone = status == 'resolved'
        ? raSuccess
        : status == 'under_review'
        ? raGold
        : colors.error;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone, Color.lerp(tone, Colors.black, .22) ?? tone],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              sameProblem
                  ? Icons.build_circle_outlined
                  : Icons.report_problem_outlined,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing
                      ? status == 'resolved'
                            ? 'Report resolved'
                            : 'Service report active'
                      : sameProblem
                      ? 'Warranty review'
                      : 'Report a service problem',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  existing
                      ? 'Follow the report and provider response until the driver confirms resolution.'
                      : 'Your report records the problem, evidence and service total at the time it is submitted.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 10,
                    height: 1.4,
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

class _RaDisputeHeading extends StatelessWidget {
  const _RaDisputeHeading({required this.title, required this.subtitle});

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
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaDisputeCard extends StatelessWidget {
  const _RaDisputeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .48)),
      ),
      child: child,
    );
  }
}

class _RaDisputeStatusCard extends StatelessWidget {
  const _RaDisputeStatusCard({
    required this.status,
    required this.reason,
    required this.tone,
  });

  final String status;
  final String reason;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: tone.withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              status == 'resolved'
                  ? Icons.task_alt_rounded
                  : status == 'under_review'
                  ? Icons.rate_review_outlined
                  : Icons.report_problem_outlined,
              color: tone,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: tone,
                    fontSize: 8.5,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.onSurface,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _RaDisputeMiniHeading extends StatelessWidget {
  const _RaDisputeMiniHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RaDisputeMoneyRow extends StatelessWidget {
  const _RaDisputeMoneyRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? colors.primary : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
