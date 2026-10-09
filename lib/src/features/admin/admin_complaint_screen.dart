part of '../../screens.dart';

class _AdminComplaintScreen extends StatefulWidget {
  const _AdminComplaintScreen({required this.requestId});

  final String requestId;

  @override
  State<_AdminComplaintScreen> createState() => _AdminComplaintScreenState();
}

class _AdminComplaintScreenState extends State<_AdminComplaintScreen> {
  String priority = 'normal';

  DateTime dueAt = DateTime.now().add(const Duration(days: 2));

  bool busy = false;

  late final review = FirebaseFirestore.instance
      .collection('complaintReviews')
      .doc(widget.requestId)
      .snapshots();

  Future<void> decide(String status) async {
    final reason = await _adminReason(context, 'Public decision / next step');

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService().reviewComplaint(
        widget.requestId,
        status: status,
        priority: priority,
        dueAt: dueAt,
        decision: reason,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint review updated.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the decision.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String dueLabel() {
    return '${dueAt.day.toString().padLeft(2, '0')}/'
        '${dueAt.month.toString().padLeft(2, '0')}/'
        '${dueAt.year}';
  }

  Color priorityColor(BuildContext context, String value) {
    final colors = Theme.of(context).colorScheme;

    return switch (value) {
      'urgent' => colors.error,
      'high' => raGold,
      'low' => colors.onSurfaceVariant,
      _ => colors.primary,
    };
  }

  String friendlyStatus(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((item) => item.isNotEmpty)
        .map((item) => '${item[0].toUpperCase()}${item.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaAdminScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Complaint Review',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _AdminComplaintHero(requestId: widget.requestId),

          const SizedBox(height: 12),

          const _AdminComplaintNotice(
            icon: Icons.gavel_outlined,
            title: 'Evidence-based review',
            message:
                'Review the driver report, provider response and invoice evidence before deciding. Admin decisions are visible to participants but do not automatically process refunds.',
            tone: raBlue,
          ),

          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 480;

              final caseButton = OutlinedButton.icon(
                onPressed: () {
                  push(context, DisputeScreen(requestId: widget.requestId));
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Case Evidence'),
              );

              final invoiceButton = OutlinedButton.icon(
                onPressed: () {
                  push(context, InvoiceScreen(requestId: widget.requestId));
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Invoice'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    caseButton,
                    const SizedBox(height: 8),
                    invoiceButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: caseButton),
                  const SizedBox(width: 8),
                  Expanded(child: invoiceButton),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          const _AdminComplaintHeading(
            title: 'Current admin review',
            subtitle:
                'Current complaint ownership, priority, deadline and published decision.',
          ),

          const SizedBox(height: 10),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: review,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _AdminComplaintNotice(
                  icon: Icons.cloud_off_outlined,
                  title: 'Review unavailable',
                  message: 'Could not load the current admin complaint review.',
                  tone: raDanger,
                );
              }

              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final data = snapshot.data?.data();

              final currentPriority = data?['priority'] as String? ?? 'normal';

              final due = data?['dueAt'] as Timestamp?;

              final decision = data?['decision'] as String? ?? '';

              return _AdminComplaintSurface(
                child: Column(
                  children: [
                    _AdminCaseRow(
                      label: 'Status',
                      value: friendlyStatus(
                        data?['status'] as String? ?? 'Not assigned',
                      ),
                    ),
                    const Divider(height: 1),
                    _AdminCaseRow(
                      label: 'Assigned admin',
                      value: data?['assignedTo'] as String? ?? 'None',
                    ),
                    const Divider(height: 1),
                    _AdminCaseRow(
                      label: 'Priority',
                      value: friendlyStatus(currentPriority),
                      valueColor: priorityColor(context, currentPriority),
                    ),
                    if (due != null) ...[
                      const Divider(height: 1),
                      _AdminCaseRow(
                        label: 'Follow-up deadline',
                        value:
                            '${due.toDate().toLocal().day.toString().padLeft(2, '0')}/'
                            '${due.toDate().toLocal().month.toString().padLeft(2, '0')}/'
                            '${due.toDate().toLocal().year}',
                      ),
                    ],
                    if (decision.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      _AdminCaseRow(label: 'Public decision', value: decision),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const _AdminComplaintHeading(
            title: 'Review controls',
            subtitle:
                'Set the next follow-up priority and deadline before recording a decision.',
          ),

          const SizedBox(height: 10),

          _AdminComplaintSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Priority for next action',
                    prefixIcon: Icon(Icons.priority_high_rounded),
                  ),
                  items: [
                    for (final value in ['low', 'normal', 'high', 'urgent'])
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.toUpperCase()),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            priority = value;
                          });
                        },
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueAt,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );

                          if (picked != null && mounted) {
                            setState(() {
                              dueAt = picked.add(
                                const Duration(hours: 23, minutes: 59),
                              );
                            });
                          }
                        },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Follow-up deadline · ${dueLabel()}'),
                ),

                const SizedBox(height: 12),

                const _AdminComplaintNotice(
                  icon: Icons.info_outline_rounded,
                  title: 'Decision reasons are required',
                  message:
                      'Starting review can reopen an existing resolved admin review. A reason is required for every recorded decision.',
                  tone: raGold,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;

              final startReview = FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        decide('under_review');
                      },
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Start Review'),
              );

              final resolve = OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        decide('resolved');
                      },
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Record Resolution'),
              );

              final dismiss = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: .45)),
                ),
                onPressed: busy
                    ? null
                    : () {
                        decide('dismissed');
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Dismiss'),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    startReview,
                    const SizedBox(height: 8),
                    resolve,
                    const SizedBox(height: 8),
                    dismiss,
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [startReview, resolve, dismiss],
              );
            },
          ),

          const SizedBox(height: 25),

          _AdminPrivateNotes(kind: 'complaint', target: widget.requestId),

          if (busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _AdminComplaintHero extends StatelessWidget {
  const _AdminComplaintHero({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _providerSurface(context),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Case review',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'JOB $requestId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .45,
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

class _AdminComplaintHeading extends StatelessWidget {
  const _AdminComplaintHeading({required this.title, required this.subtitle});

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

class _AdminComplaintSurface extends StatelessWidget {
  const _AdminComplaintSurface({required this.child});

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

class _AdminComplaintNotice extends StatelessWidget {
  const _AdminComplaintNotice({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tone.withValues(alpha: .17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 19),
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

class _AdminCaseRow extends StatelessWidget {
  const _AdminCaseRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
