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
  State<DisputeScreen> createState() =>
      _DisputeScreenState();
}

class _DisputeScreenState
    extends State<DisputeScreen> {
  final description =
      TextEditingController();

  final response =
      TextEditingController();

  final photos = <String>[];

  String reason = 'extra_charge';
  String responseType = 'review';

  bool busy = false;
  bool canReport = false;

  late final job =
      FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId);

  late final caseRef =
      job
          .collection('disputes')
          .doc('case');

  late final caseStream =
      caseRef.snapshots();

  static const reasons = {
    'same_problem':
        'Same problem again / Warranty review',
    'extra_charge':
        'Extra money requested',
    'repair_quality':
        'Repair problem',
    'incomplete_service':
        'Service incomplete',
    'other':
        'Other problem',
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
          .then(
        (snapshot) {
          if (!mounted) return;

          final data =
              snapshot.data();

          setState(() {
            canReport =
                data?['driverId'] ==
                        FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid &&
                    (data?['status'] ==
                            'completed' ||
                        data?['completionState'] ==
                            'pending');
          });
        },
      ).catchError(
        (Object error) {},
      ),
    );
  }

  @override
  void dispose() {
    description.dispose();
    response.dispose();

    super.dispose();
  }

  Future<void> perform(
    Future<void> Function() action,
  ) async {
    setState(() {
      busy = true;
    });

    try {
      await action();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

  Future<void> addPhoto() =>
      perform(
        () async {
          final photo =
              await ImagePicker()
                  .pickImage(
            source:
                ImageSource.gallery,
            imageQuality: 75,
            maxWidth: 1400,
          );

          if (photo == null) {
            return;
          }

          final encoded =
              await PhotoUploadService()
                  .prepareVehiclePhoto(
            photo,
          );

          if (mounted) {
            setState(() {
              photos.add(encoded);
            });
          }
        },
      );

  Future<void> submit() async {
    if (reason ==
            'same_problem' &&
        photos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Add a photo showing the repeated problem.',
          ),
        ),
      );

      return;
    }

    if (description.text
            .trim()
            .length <
        10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Describe the problem in at least 10 characters.',
          ),
        ),
      );

      return;
    }

    await perform(
      () async {
        await FirebaseFirestore
            .instance
            .runTransaction(
          (transaction) async {
            final request =
                (await transaction
                        .get(job))
                    .data();

            final existing =
                await transaction
                    .get(caseRef);

            if (existing.exists ||
                request == null ||
                (request['status'] !=
                        'completed' &&
                    request['completionState'] !=
                        'pending') ||
                request['driverId'] !=
                    FirebaseAuth
                        .instance
                        .currentUser
                        ?.uid) {
              throw StateError(
                'Unavailable',
              );
            }

            transaction.set(
              caseRef,
              {
                'driverId':
                    request[
                        'driverId'],
                'providerId':
                    request[
                        'providerId'],
                'reason':
                    reason,
                'description':
                    description
                        .text
                        .trim(),
                'photos':
                    List<String>.from(
                  photos,
                ),
                'status':
                    'open',
                'providerResponse':
                    '',
                'resolution':
                    '',
                'approvedTotal':
                    request[
                            'estimatedCost'] ??
                        0,
                'finalTotal':
                    request[
                            'finalCost'] ??
                        request[
                            'estimatedCost'] ??
                        0,
                'createdAt':
                    FieldValue
                        .serverTimestamp(),
                'updatedAt':
                    FieldValue
                        .serverTimestamp(),
              },
            );
          },
        );
      },
    );
  }

  Future<void> reply() async {
    if (response.text
            .trim()
            .length <
        10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Add a response of at least 10 characters.',
          ),
        ),
      );

      return;
    }

    await perform(
      () => caseRef.update({
        'providerResponse':
            '${responseType == 'free_recheck' ? 'Free recheck offered' : responseType == 'not_covered' ? 'Coverage declined' : 'Review response'}: ${response.text.trim()}',
        'status':
            'under_review',
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }),
    );
  }

  Future<void> resolve() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color:
                  raSuccessPale,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: const Icon(
              Icons
                  .task_alt_rounded,
              color:
                  raSuccess,
            ),
          ),
          title: const Text(
            'Has the problem been resolved?',
          ),
          content: const Text(
            'Confirm only when you are satisfied with the resolution. This records your confirmation; it does not modify the invoice or automatically process a refund.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'Back',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Confirm Resolved',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    await perform(
      () => caseRef.update({
        'status':
            'resolved',
        'resolution':
            'Driver confirmed the problem is resolved.',
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }),
    );
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return switch (status) {
      'resolved' =>
        raSuccess,
      'under_review' =>
        raGold,
      _ => colors.error,
    };
  }

  Widget _reportForm(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration: BoxDecoration(
            color: colors
                .primaryContainer
                .withValues(
              alpha: .28,
            ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons
                    .info_outline_rounded,
                color:
                    colors.primary,
              ),
              const SizedBox(
                width: RaSpace.sm,
              ),
              const Expanded(
                child: Text(
                  'Your report is shared with the assigned provider. Avoid adding unrelated personal information.',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: RaSpace.xl,
        ),

        Text(
          'What went wrong?',
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

        DropdownButtonFormField<
            String>(
          initialValue: reason,
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText:
                'Problem type',
            prefixIcon:
                Icon(
              Icons
                  .report_problem_outlined,
            ),
          ),
          items: reasons.entries
              .map(
                (entry) =>
                    DropdownMenuItem<
                        String>(
                  value:
                      entry.key,
                  child: Text(
                    entry.value,
                  ),
                ),
              )
              .toList(),
          onChanged: busy
              ? null
              : (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(() {
                    reason =
                        value;
                  });
                },
        ),

        const SizedBox(
          height: RaSpace.md,
        ),

        TextField(
          controller:
              description,
          enabled: !busy,
          maxLength: 1000,
          minLines: 4,
          maxLines: 7,
          textCapitalization:
              TextCapitalization
                  .sentences,
          decoration:
              const InputDecoration(
            labelText:
                'What happened?',
            hintText:
                'Explain the problem and what you expected to happen.',
            alignLabelWithHint:
                true,
            prefixIcon: Padding(
              padding:
                  EdgeInsets.only(
                bottom: 85,
              ),
              child: Icon(
                Icons
                    .description_outlined,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: RaSpace.lg,
        ),

        Row(
          children: [
            Expanded(
              child: Text(
                'Evidence',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${photos.length}/2',
              style: theme
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                color:
                    colors.primary,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: RaSpace.sm,
        ),

        RevisionEvidencePhotos(
          photos: photos,
        ),

        if (photos
            .isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (var index =
                      0;
                  index <
                      photos.length;
                  index++)
                TextButton.icon(
                  onPressed:
                      busy
                          ? null
                          : () {
                              setState(
                                () {
                                  photos.removeAt(
                                    index,
                                  );
                                },
                              );
                            },
                  icon: const Icon(
                    Icons
                        .close_rounded,
                    size: 16,
                  ),
                  label: Text(
                    'Remove ${index + 1}',
                  ),
                ),
            ],
          ),

        OutlinedButton.icon(
          onPressed:
              busy ||
                      photos.length >=
                          2
                  ? null
                  : addPhoto,
          icon: const Icon(
            Icons
                .add_photo_alternate_outlined,
          ),
          label: const Text(
            'Add Evidence Photo',
          ),
        ),

        const SizedBox(
          height: RaSpace.xl,
        ),

        FilledButton.icon(
          onPressed:
              busy
                  ? null
                  : submit,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Colors.white,
                  ),
                )
              : const Icon(
                  Icons
                      .send_rounded,
                ),
          label: const Text(
            'Submit Report',
          ),
        ),
      ],
    );
  }

  Widget _existingReport(
    BuildContext context,
    Map<String, dynamic> report,
    String? uid,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final reportStatus =
        report['status']
                ?.toString() ??
            'open';

    final color =
        _statusColor(
      context,
      reportStatus,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.all(
            RaSpace.lg,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: .08,
            ),
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: color
                  .withValues(
                alpha: .24,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: color
                      .withValues(
                    alpha: .12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  reportStatus ==
                          'resolved'
                      ? Icons
                          .task_alt_rounded
                      : reportStatus ==
                              'under_review'
                          ? Icons
                              .rate_review_outlined
                          : Icons
                              .report_problem_outlined,
                  color: color,
                ),
              ),

              const SizedBox(
                width: RaSpace.md,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportStatus
                          .replaceAll(
                            '_',
                            ' ',
                          )
                          .toUpperCase(),
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        color: color,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      reasons[
                              report[
                                  'reason']] ??
                          'Other problem',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: RaSpace.lg,
        ),

        _DisputeContentCard(
          title:
              'Driver report',
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                report['description']
                        as String? ??
                    '',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  height: 1.45,
                ),
              ),

              if ((report['photos']
                          as List? ??
                      [])
                  .isNotEmpty) ...[
                const SizedBox(
                  height:
                      RaSpace.md,
                ),
                RevisionEvidencePhotos(
                  photos:
                      List<String>.from(
                    report['photos']
                            as List? ??
                        [],
                  ),
                ),
              ],

              const SizedBox(
                height:
                    RaSpace.md,
              ),

              Divider(
                color: colors
                    .outlineVariant,
              ),

              _DisputeMoneyRow(
                label:
                    'Approved total at reporting',
                value:
                    'Rs. ${report['approvedTotal']}',
              ),

              _DisputeMoneyRow(
                label:
                    'Final invoice at reporting',
                value:
                    'Rs. ${report['finalTotal']}',
                strong:
                    true,
              ),
            ],
          ),
        ),

        if ((report['providerResponse']
                    as String? ??
                '')
            .isNotEmpty) ...[
          const SizedBox(
            height: RaSpace.md,
          ),
          _DisputeContentCard(
            title:
                'Provider response',
            child: Text(
              report['providerResponse']
                  as String,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                height: 1.45,
              ),
            ),
          ),
        ],

        if (reportStatus !=
                'resolved' &&
            uid ==
                report['providerId']) ...[
          const SizedBox(
            height: RaSpace.xl,
          ),

          Text(
            'Respond to report',
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

          DropdownButtonFormField<
              String>(
            initialValue:
                responseType,
            decoration:
                const InputDecoration(
              labelText:
                  'Proposed resolution',
              prefixIcon:
                  Icon(
                Icons
                    .handshake_outlined,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'review',
                child: Text(
                  'Review / discuss',
                ),
              ),
              DropdownMenuItem(
                value:
                    'free_recheck',
                child: Text(
                  'Offer free recheck',
                ),
              ),
              DropdownMenuItem(
                value:
                    'not_covered',
                child: Text(
                  'Not covered - explain why',
                ),
              ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value !=
                        null) {
                      setState(() {
                        responseType =
                            value;
                      });
                    }
                  },
          ),

          const SizedBox(
            height: RaSpace.sm,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(
                alpha: .42,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Text(
              'Do not add charges to the completed invoice. Any paid follow-up requires a separate request and driver-approved quote.',
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          TextField(
            controller:
                response,
            enabled: !busy,
            maxLength: 900,
            minLines: 3,
            maxLines: 6,
            decoration:
                const InputDecoration(
              labelText:
                  'Response / proposed resolution',
              alignLabelWithHint:
                  true,
            ),
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          FilledButton.icon(
            onPressed:
                busy
                    ? null
                    : reply,
            icon: const Icon(
              Icons.send_rounded,
            ),
            label: const Text(
              'Send Response',
            ),
          ),
        ],

        if (reportStatus !=
                'resolved' &&
            uid ==
                report['driverId']) ...[
          const SizedBox(
            height: RaSpace.lg,
          ),
          FilledButton.icon(
            onPressed:
                busy
                    ? null
                    : resolve,
            icon: const Icon(
              Icons
                  .task_alt_rounded,
            ),
            label: const Text(
              'Confirm Problem Resolved',
            ),
          ),
        ],

        if (reportStatus ==
            'resolved') ...[
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
              color:
                  raSuccessPale,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .check_circle_outline_rounded,
                  color:
                      raSuccess,
                ),
                const SizedBox(
                  width:
                      RaSpace.sm,
                ),
                Expanded(
                  child: Text(
                    report['resolution']
                            as String? ??
                        'Resolved',
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(
          height: RaSpace.md,
        ),

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
            'View Invoice & Approval History',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Service Problem Report',
        ),
      ),

      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: caseStream,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons
                  .cloud_off_outlined,
              title:
                  'Unable to load report',
              message:
                  'Check your connection and try again.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final report =
              snapshot.data!.data();

          final uid =
              FirebaseAuth
                  .instance
                  .currentUser
                  ?.uid;

          return ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              RaSpace.lg,
              RaSpace.md,
              RaSpace.lg,
              RaSpace.xxxl,
            ),
            children: [
              Container(
                padding:
                    const EdgeInsets
                        .all(
                  RaSpace.xl,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment
                            .topLeft,
                    end:
                        Alignment
                            .bottomRight,
                    colors: [
                      colors.primary,
                      const Color(
                        0xFF007D70,
                      ),
                    ],
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .14,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          17,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .support_agent_outlined,
                        color:
                            Colors.white,
                        size:
                            27,
                      ),
                    ),

                    const SizedBox(
                      height:
                          RaSpace.lg,
                    ),

                    Text(
                      'Service support',
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Job ${widget.requestId}',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .82,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Report service issues, exchange evidence with the provider and record the resolution.',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: .82,
                        ),
                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              StreamBuilder<
                  DocumentSnapshot<
                      Map<String,
                          dynamic>>>(
                stream:
                    job.snapshots(),
                builder: (
                  context,
                  jobSnapshot,
                ) {
                  final data =
                      jobSnapshot.data
                          ?.data();

                  if (data == null) {
                    return const SizedBox
                        .shrink();
                  }

                  return ServiceWarranty(
                    requestId:
                        widget
                            .requestId,
                    job: data,
                  );
                },
              ),

              if (report == null &&
                  canReport) ...[
                const SizedBox(
                  height:
                      RaSpace.xl,
                ),
                _reportForm(
                  context,
                ),
              ] else if (report !=
                  null) ...[
                const SizedBox(
                  height:
                      RaSpace.xl,
                ),
                _existingReport(
                  context,
                  report,
                  uid,
                ),
              ] else ...[
                const SizedBox(
                  height:
                      RaSpace.xl,
                ),
                const EmptyState(
                  icon: Icons
                      .report_problem_outlined,
                  title:
                      'No problem report',
                  message:
                      'No driver problem report has been submitted for this job.',
                ),
              ],

              if (report != null) ...[
                const SizedBox(
                  height:
                      RaSpace.xl,
                ),
                StreamBuilder<
                    DocumentSnapshot<
                        Map<String,
                            dynamic>>>(
                  stream:
                      FirebaseFirestore
                          .instance
                          .collection(
                            'complaintReviews',
                          )
                          .doc(
                            widget
                                .requestId,
                          )
                          .snapshots(),
                  builder: (
                    context,
                    reviewSnapshot,
                  ) {
                    if (reviewSnapshot
                        .hasError) {
                      return const InlineMessage(
                        text:
                            'Could not load admin review.',
                        error:
                            true,
                      );
                    }

                    final review =
                        reviewSnapshot
                            .data
                            ?.data();

                    if (review ==
                        null) {
                      return const SizedBox
                          .shrink();
                    }

                    return _DisputeContentCard(
                      title:
                          'Admin review',
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Status: ${review['status'] ?? 'Not specified'}',
                            style: theme
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                          if ((review['decision']
                                      as String? ??
                                  '')
                              .isNotEmpty) ...[
                            const SizedBox(
                              height:
                                  RaSpace
                                      .sm,
                            ),
                            Text(
                              review['decision']
                                  as String,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],

              if (busy) ...[
                const SizedBox(
                  height:
                      RaSpace.md,
                ),
                const LinearProgressIndicator(
                  minHeight: 3,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DisputeContentCard
    extends StatelessWidget {
  const _DisputeContentCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: RaSpace.md,
          ),
          child,
        ],
      ),
    );
  }
}

class _DisputeMoneyRow
    extends StatelessWidget {
  const _DisputeMoneyRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}