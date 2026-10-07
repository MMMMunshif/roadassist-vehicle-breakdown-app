part of '../../screens.dart';

class _AdminComplaintScreen
    extends StatefulWidget {
  const _AdminComplaintScreen({
    required this.requestId,
  });

  final String requestId;

  @override
  State<_AdminComplaintScreen>
      createState() =>
          _AdminComplaintScreenState();
}

class _AdminComplaintScreenState
    extends State<_AdminComplaintScreen> {
  String priority = 'normal';

  DateTime dueAt = DateTime.now().add(
    const Duration(days: 2),
  );

  bool busy = false;

  late final review =
      FirebaseFirestore.instance
          .collection(
            'complaintReviews',
          )
          .doc(widget.requestId)
          .snapshots();

  Future<void> decide(
    String status,
  ) async {
    final reason =
        await _adminReason(
      context,
      'Public decision / next step',
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await AdminService()
          .reviewComplaint(
        widget.requestId,
        status: status,
        priority: priority,
        dueAt: dueAt,
        decision: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Complaint review updated.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the decision.',
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

  String dueLabel() {
    return '${dueAt.day.toString().padLeft(2, '0')}/'
        '${dueAt.month.toString().padLeft(2, '0')}/'
        '${dueAt.year}';
  }

  Color priorityColor(
    BuildContext context,
    String value,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return switch (value) {
      'urgent' => colors.error,
      'high' => raGold,
      'low' =>
        colors.onSurfaceVariant,
      _ => colors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Complaint Review',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              RaSpace.xl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  colors.primary,
                  const Color(
                    0xFF007D70,
                  ),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                24,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: .14,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(16),
                  ),
                  child: const Icon(
                    Icons
                        .fact_check_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  height: RaSpace.lg,
                ),
                Text(
                  'Case review',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Job ${widget.requestId}',
                  style: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    color: Colors.white
                        .withValues(
                      alpha: .82,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: .4),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons
                      .gavel_outlined,
                  size: 19,
                ),
                SizedBox(
                  width: RaSpace.sm,
                ),
                Expanded(
                  child: Text(
                    'Review the driver report, provider response and invoice evidence before deciding. Admin decisions are visible to participants but do not automatically process refunds.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.xl,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed: () => push(
                    context,
                    DisputeScreen(
                      requestId:
                          widget.requestId,
                    ),
                  ),
                  icon: const Icon(
                    Icons
                        .report_problem_outlined,
                  ),
                  label: const Text(
                    'View Case Evidence',
                  ),
                ),
              ),
              const SizedBox(
                width: RaSpace.sm,
              ),
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed: () => push(
                    context,
                    InvoiceScreen(
                      requestId:
                          widget.requestId,
                    ),
                  ),
                  icon: const Icon(
                    Icons
                        .receipt_long_outlined,
                  ),
                  label: const Text(
                    'View Invoice',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Current admin review',
            style: theme
                .textTheme.titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          StreamBuilder<
            DocumentSnapshot<
              Map<String, dynamic>
            >
          >(
            stream: review,
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.hasError) {
                return const InlineMessage(
                  text:
                      'Could not load admin review.',
                  error: true,
                );
              }

              final data =
                  snapshot.data?.data();

              final currentPriority =
                  data?['priority']
                          as String? ??
                      'normal';

              final due =
                  data?['dueAt']
                      as Timestamp?;

              return Container(
                padding:
                    const EdgeInsets.all(
                  RaSpace.lg,
                ),
                decoration:
                    BoxDecoration(
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
                child: Column(
                  children: [
                    _AdminCaseRow(
                      label: 'Status',
                      value:
                          data?['status']
                                  as String? ??
                              'Not assigned',
                    ),
                    _AdminCaseRow(
                      label:
                          'Assigned admin',
                      value:
                          data?['assignedTo']
                                  as String? ??
                              'None',
                    ),
                    _AdminCaseRow(
                      label: 'Priority',
                      value:
                          currentPriority,
                      valueColor:
                          priorityColor(
                        context,
                        currentPriority,
                      ),
                    ),
                    if (due != null)
                      _AdminCaseRow(
                        label:
                            'Follow-up deadline',
                        value: due
                            .toDate()
                            .toLocal()
                            .toString()
                            .split(' ')
                            .first,
                      ),
                    if ((data?['decision']
                                as String? ??
                            '')
                        .isNotEmpty)
                      _AdminCaseRow(
                        label:
                            'Public decision',
                        value:
                            data!['decision']
                                as String,
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Text(
            'Review controls',
            style: theme
                .textTheme.titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          Container(
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
                color: colors.outlineVariant
                    .withValues(
                  alpha: .6,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                DropdownButtonFormField<
                  String
                >(
                  initialValue: priority,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Priority for next action',
                    prefixIcon: Icon(
                      Icons
                          .priority_high_rounded,
                    ),
                  ),
                  items: [
                    for (final value in [
                      'low',
                      'normal',
                      'high',
                      'urgent',
                    ])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value
                              .toUpperCase(),
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            priority =
                                value;
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
                          final picked =
                              await showDatePicker(
                            context: context,
                            initialDate:
                                dueAt,
                            firstDate:
                                DateTime.now(),
                            lastDate: DateTime
                                .now()
                                .add(
                              const Duration(
                                days: 30,
                              ),
                            ),
                          );

                          if (picked !=
                                  null &&
                              mounted) {
                            setState(() {
                              dueAt =
                                  picked.add(
                                const Duration(
                                  hours: 23,
                                  minutes: 59,
                                ),
                              );
                            });
                          }
                        },
                  icon: const Icon(
                    Icons
                        .calendar_month_outlined,
                  ),
                  label: Text(
                    'Follow-up deadline: ${dueLabel()}',
                  ),
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                const InlineMessage(
                  icon: Icons
                      .info_outline_rounded,
                  text:
                      'Starting review can reopen an existing resolved admin review. A reason is required for every decision.',
                ),
              ],
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          Wrap(
            spacing: RaSpace.sm,
            runSpacing: RaSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => decide(
                        'under_review',
                      ),
                icon: const Icon(
                  Icons
                      .assignment_ind_outlined,
                ),
                label: const Text(
                  'Assign to Me / Start Review',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => decide(
                        'resolved',
                      ),
                icon: const Icon(
                  Icons
                      .task_alt_rounded,
                ),
                label: const Text(
                  'Record Resolution',
                ),
              ),
              OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      colors.error,
                ),
                onPressed: busy
                    ? null
                    : () => decide(
                        'dismissed',
                      ),
                icon: const Icon(
                  Icons
                      .cancel_outlined,
                ),
                label: const Text(
                  'Dismiss with Reason',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.xl,
          ),

          _AdminPrivateNotes(
            kind: 'complaint',
            target: widget.requestId,
          ),

          if (busy) ...[
            const SizedBox(
              height: RaSpace.md,
            ),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _AdminCaseRow
    extends StatelessWidget {
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
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme.bodySmall
                  ?.copyWith(
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style: Theme.of(context)
                  .textTheme.bodyMedium
                  ?.copyWith(
                color: valueColor,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}