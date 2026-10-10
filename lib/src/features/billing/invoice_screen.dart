part of '../../screens.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> request;

  bool saving = false;
  bool exporting = false;
  String? offerKey;
  Future<Map<String, dynamic>>? offerFuture;

  Future<Map<String, dynamic>> billOffer(Map<String, dynamic> data) {
    final key = '${data['approvedRepairId']}/${data['selectedQuoteId']}';
    if (offerFuture == null || offerKey != key) {
      offerKey = key;
      offerFuture = approvedOffer(data);
    }
    return offerFuture!;
  }

  Future<Map<String, dynamic>> approvedOffer(Map<String, dynamic> data) async {
    final repairId = data['approvedRepairId'];
    final quoteId = data['selectedQuoteId'];
    final id = repairId ?? quoteId;
    if (id is! String || id.isEmpty) return data;
    final doc = await FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .collection(repairId != null ? 'repairQuotes' : 'quotes')
        .doc(id)
        .get();
    if (!doc.exists) {
      throw StateError('Approved warranty record is unavailable.');
    }
    return doc.data()!;
  }

  Future<void> exportBill(
    Map<String, dynamic> data, {
    required bool share,
  }) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final offer = await approvedOffer(data);
      final bill = ServiceInvoice.fromRequest(
        widget.requestId,
        data,
        approvedOffer: offer,
      );
      final bytes = await InvoicePdfService.generate(bill);
      if (!mounted) return;
      final box = context.findRenderObject();
      final bounds = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final done = share
          ? await InvoicePdfService.share(bytes, bill.filename, bounds: bounds)
          : await InvoicePdfService.download(bytes, bill.filename);
      if (mounted && done && !share) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to export invoice. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();

    request = RequestService().watchRequest(widget.requestId);
  }

  Future<void> record(String method) async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      await RequestService().recordPayment(widget.requestId, method);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RaScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Service Invoice',
          style: GoogleFonts.plusJakartaSans(
            fontSize: providerFontSize(context, 19),
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: request,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load invoice',
                message: 'Reconnect to the internet and try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Invoice unavailable',
                message: 'This service record could not be found.',
              ),
            );
          }

          if (data['status'] != 'completed') {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.hourglass_top_rounded,
                title: 'Invoice not ready',
                message:
                    'The final service invoice becomes available after completion.',
              ),
            );
          }

          final uid = FirebaseAuth.instance.currentUser?.uid;

          final provider = uid != null && uid == data['providerId'];

          final driver = uid != null && uid == data['driverId'];

          final driverReported = data['driverReportedPayment'] == true;

          final providerConfirmed = data['providerConfirmedPayment'] == true;

          final paymentMethod = data['paymentMethod'] as String?;

          ServiceInvoice bill;
          try {
            bill = ServiceInvoice.fromRequest(
              widget.requestId,
              data,
              approvedOffer:
                  (data['approvedRepairId'] != null ||
                      data['selectedQuoteId'] != null)
                  ? <String, dynamic>{}
                  : null,
            );
          } catch (_) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Invoice unavailable',
              message: 'A valid final amount has not been recorded.',
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: billOffer(data),
                builder: (context, offer) => Column(
                  children: [
                    InvoiceBillView(
                      invoice: offer.hasData
                          ? ServiceInvoice.fromRequest(
                              widget.requestId,
                              data,
                              approvedOffer: offer.data,
                            )
                          : bill,
                      busy: exporting,
                      onDownload: provider || driver
                          ? () => exportBill(data, share: false)
                          : null,
                      onShare: provider || driver
                          ? () => exportBill(data, share: true)
                          : null,
                    ),
                    if (offer.hasError)
                      TextButton(
                        onPressed: () => setState(() => offerFuture = null),
                        child: const Text('Retry loading approved warranty'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title: 'Payment status',
                subtitle:
                    'RoadAssist records cash or external payment confirmation only.',
              ),

              const SizedBox(height: 10),

              _RaInvoicePaymentCard(
                driverReported: driverReported,
                providerConfirmed: providerConfirmed,
                paymentMethod: paymentMethod,
              ),

              if (driver && !driverReported) ...[
                const SizedBox(height: 11),

                _RaInvoiceSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Record Payment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: providerFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Only record payment after money has actually been paid to the provider.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: providerFontSize(context, 8.5),
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                record('cash');
                              },
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('I Paid Cash'),
                      ),

                      const SizedBox(height: 7),

                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                record('external');
                              },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('I Paid Outside the App'),
                      ),
                    ],
                  ),
                ),
              ],

              if (provider && driverReported && !providerConfirmed) ...[
                const SizedBox(height: 11),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving || paymentMethod == null
                        ? null
                        : () {
                            record(paymentMethod);
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Confirm Payment Received'),
                  ),
                ),
              ],

              if (saving) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],

              const SizedBox(height: 24),

              const _RaInvoiceSectionHeading(
                title: 'Warranty',
                subtitle:
                    'Any agreed service warranty is shown from the completed job record.',
              ),

              const SizedBox(height: 10),

              ServiceWarranty(requestId: widget.requestId, job: data),

              if (driver) ...[
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      push(
                        context,
                        DisputeScreen(
                          requestId: widget.requestId,
                          sameProblem: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.published_with_changes_outlined),
                    label: const Text('Same Problem / Warranty Review'),
                  ),
                ),
              ],

              if (driver || provider) ...[
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      push(context, DisputeScreen(requestId: widget.requestId));
                    },
                    icon: const Icon(Icons.report_problem_outlined),
                    label: Text(
                      driver
                          ? 'Report a Problem / View Report'
                          : 'View Service Problem Report',
                    ),
                  ),
                ),
              ],

              if (data['workflowVersion'] == 2) ...[
                const SizedBox(height: 25),

                const _RaInvoiceSectionHeading(
                  title: 'Approval history',
                  subtitle:
                      'Original offers and later repair revisions recorded for this service.',
                ),

                const SizedBox(height: 10),

                _InvoiceApprovalHistory(
                  requestId: widget.requestId,
                  selectedQuoteId: data['selectedQuoteId'] as String?,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RaInvoiceSectionHeading extends StatelessWidget {
  const _RaInvoiceSectionHeading({required this.title, required this.subtitle});

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
            fontSize: providerFontSize(context, 16.5),
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: providerFontSize(context, 9),
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaInvoiceSurface extends StatelessWidget {
  const _RaInvoiceSurface({required this.child});

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
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _RaInvoicePaymentCard extends StatelessWidget {
  const _RaInvoicePaymentCard({
    required this.driverReported,
    required this.providerConfirmed,
    required this.paymentMethod,
  });

  final bool driverReported;
  final bool providerConfirmed;
  final String? paymentMethod;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final Color tone;
    final IconData icon;
    final String title;
    final String message;

    if (providerConfirmed) {
      tone = raSuccess;
      icon = Icons.verified_outlined;
      title = 'Payment confirmed';
      message = 'The provider confirmed that payment was received.';
    } else if (driverReported) {
      tone = raGold;
      icon = Icons.hourglass_top_rounded;
      title = 'Awaiting provider confirmation';
      message =
          'The driver reported payment${paymentMethod == null ? '' : ' by ${paymentMethod!.replaceAll('_', ' ')}'}.';
    } else {
      tone = colors.primary;
      icon = Icons.payments_outlined;
      title = 'Payment not recorded';
      message = 'No cash or external payment has been recorded for this job.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: providerFontSize(context, 10.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: providerFontSize(context, 8.6),
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'RoadAssist does not process an online payment for this record.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: providerFontSize(context, 7.8),
                    height: 1.4,
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

class _InvoiceApprovalHistory extends StatefulWidget {
  const _InvoiceApprovalHistory({
    required this.requestId,
    this.selectedQuoteId,
  });

  final String requestId;
  final String? selectedQuoteId;

  @override
  State<_InvoiceApprovalHistory> createState() =>
      _InvoiceApprovalHistoryState();
}

class _InvoiceApprovalHistoryState extends State<_InvoiceApprovalHistory> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> revisions;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> decisions;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? initialQuote;

  @override
  void initState() {
    super.initState();

    final ref = FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId);

    revisions = ref.collection('repairQuotes').snapshots();

    decisions = ref.collection('repairDecisions').snapshots();

    initialQuote = widget.selectedQuoteId == null
        ? null
        : ref.collection('quotes').doc(widget.selectedQuoteId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return _RaInvoiceSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (initialQuote != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: initialQuote,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const InlineMessage(
                    icon: Icons.error_outline_rounded,
                    text: 'Could not load the original approved quote.',
                  );
                }

                final quote = snapshot.data?.data();

                if (quote == null) {
                  return const LinearProgressIndicator();
                }

                final quoteType = quote['quoteType'] as String? ?? 'service';

                return _RaInvoiceApprovalEntry(
                  icon: Icons.request_quote_outlined,
                  title:
                      'Original approved ${quoteType == 'inspection' ? 'inspection' : 'service'} offer',
                  amount: 'Rs. ${quote['total'] ?? 0}',
                  message: quote['notes']?.toString().trim().isNotEmpty == true
                      ? '${quote['notes']}'
                      : 'No additional quote notes recorded.',
                  tone: Theme.of(context).colorScheme.primary,
                );
              },
            ),

          if (initialQuote != null) const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: decisions,
            builder: (context, decisionSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: revisions,
                builder: (context, revisionSnapshot) {
                  if (revisionSnapshot.hasError || decisionSnapshot.hasError) {
                    return const InlineMessage(
                      icon: Icons.history_toggle_off_rounded,
                      text: 'Could not load quote approval history.',
                    );
                  }

                  if (!revisionSnapshot.hasData || !decisionSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final outcomes = {
                    for (final decision in decisionSnapshot.data!.docs)
                      decision.id: decision.data(),
                  };

                  final entries = revisionSnapshot.data!.docs.toList();

                  entries.sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)
                        ?.toDate();

                    final bTime = (b.data()['createdAt'] as Timestamp?)
                        ?.toDate();

                    if (aTime == null && bTime == null) {
                      return 0;
                    }

                    if (aTime == null) {
                      return 1;
                    }

                    if (bTime == null) {
                      return -1;
                    }

                    return aTime.compareTo(bTime);
                  });

                  if (entries.isEmpty) {
                    return Text(
                      'No repair revisions were proposed.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: providerFontSize(context, 8.8),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < entries.length; index++) ...[
                        if (index > 0) const SizedBox(height: 10),

                        _RaInvoiceRevisionEntry(
                          revision: entries[index].data(),
                          decision: outcomes[entries[index].id],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RaInvoiceApprovalEntry extends StatelessWidget {
  const _RaInvoiceApprovalEntry({
    required this.icon,
    required this.title,
    required this.amount,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String amount;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tone.withValues(alpha: .14)),
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
                    fontSize: providerFontSize(context, 9.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  amount,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: providerFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: providerFontSize(context, 8.2),
                    height: 1.4,
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

class _RaInvoiceRevisionEntry extends StatelessWidget {
  const _RaInvoiceRevisionEntry({
    required this.revision,
    required this.decision,
  });

  final Map<String, dynamic> revision;

  final Map<String, dynamic>? decision;

  @override
  Widget build(BuildContext context) {
    final outcome = decision?['decision'] as String? ?? 'not approved';

    final color = switch (outcome) {
      'approved' => raSuccess,
      'rejected' => raDanger,
      _ => raGold,
    };

    final icon = switch (outcome) {
      'approved' => Icons.check_circle_outline_rounded,
      'rejected' => Icons.cancel_outlined,
      _ => Icons.schedule_outlined,
    };

    final timestamp =
        decision?['createdAt'] as Timestamp? ??
        revision['createdAt'] as Timestamp?;

    final value = timestamp?.toDate().toLocal();

    final dateLabel = value == null
        ? 'Decision time unavailable'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

    final previous = revision['previousTotal'] ?? 0;

    final total = revision['total'] ?? 0;

    final work = revision['diagnosisAndWork']?.toString().trim() ?? '';

    final reason = revision['changeReason']?.toString().trim() ?? '';

    final photos = List<String>.from(
      revision['evidencePhotoData'] as List? ?? const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RaInvoiceApprovalEntry(
          icon: icon,
          title: outcome.replaceAll('_', ' ').toUpperCase(),
          amount: 'Rs. $previous → Rs. $total',
          message: [
            if (work.isNotEmpty) work,
            if (reason.isNotEmpty) 'Reason: $reason',
            dateLabel,
          ].join('\n'),
          tone: color,
        ),

        if (photos.isNotEmpty) ...[
          const SizedBox(height: 7),
          RevisionEvidencePhotos(photos: photos),
        ],
      ],
    );
  }
}
