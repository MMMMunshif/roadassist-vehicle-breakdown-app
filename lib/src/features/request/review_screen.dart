part of '../../screens.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.draft, this.compact = false});

  final RequestDraft draft;
  final bool compact;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Map<String, dynamic>? visitQuote;
  String? visitFeeError;
  bool loadingVisitFee = false;
  Future<void> loadVisitFee() async {
    if (loadingVisitFee) return;
    setState(() {
      loadingVisitFee = true;
      visitFeeError = null;
      visitQuote = null;
    });
    try {
      final quote = await VisitBillingService().send('prepare', {
        'providerId': widget.draft.preferredProviderId,
        'latitude': widget.draft.latitude,
        'longitude': widget.draft.longitude,
      });
      if (mounted) setState(() => visitQuote = quote);
    } catch (error) {
      if (mounted)
        setState(
          () => visitFeeError = _workflowError(
            error,
            'Unable to calculate the visit fee.',
          ),
        );
    } finally {
      if (mounted) setState(() => loadingVisitFee = false);
    }
  }

  bool submitting = false;
  bool offline = false;
  bool checkingSubmission = false;
  String? connectionNotice;
  late final RequestDraftStore draftStore = RequestDraftStore();

  Future<void> refreshConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted)
      setState(() {
        offline =
            results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
      });
  }

  Future<void> reconcileSubmission() async {
    if (submitting || !mounted) return;
    final id = await draftStore.submissionId();
    if (id == null || !mounted) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() {
      submitting = true;
      checkingSubmission = true;
      connectionNotice = 'Checking whether your last request was received...';
    });
    try {
      final received = await RequestService().findSubmittedRequest(id);
      if (!mounted) return;
      if (received != null) {
        await draftStore.clear();
        if (mounted)
          replace(
            context,
            RealtimeDriverRequestDetailsScreen(
              requestId: received,
              data: const {},
            ),
          );
      } else {
        setState(() {
          connectionNotice =
              'Connection restored. Review your draft and tap Submit when ready.';
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          connectionNotice =
              'Unable to confirm submission. Reconnect and try again safely.';
        });
    } finally {
      if (mounted)
        setState(() {
          submitting = false;
          checkingSubmission = false;
        });
    }
  }

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  bool get readyToSubmit =>
      widget.draft.modelYear.trim().isNotEmpty &&
      widget.draft.registration.trim().isNotEmpty &&
      !widget.draft.location.startsWith('Select current GPS');

  bool get specificProvider =>
      widget.draft.preferredProviderId.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(loadVisitFee());

    unawaited(draftStore.save(widget.draft));
    unawaited(
      refreshConnection().then((_) {
        if (!offline) return reconcileSubmission();
      }),
    );
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) return;
      final disconnected =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      setState(() {
        offline = disconnected;
        if (!disconnected)
          connectionNotice =
              'Connection restored. Review and submit when ready.';
      });
      if (!disconnected) unawaited(reconcileSubmission());
    });
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();

    super.dispose();
  }

  Future<void> submitRequest({bool autoRetry = false}) async {
    if (submitting) return;

    if (visitQuote == null ||
        (visitQuote!['expiresAtMs'] as int) <=
            DateTime.now().millisecondsSinceEpoch) {
      await loadVisitFee();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review the refreshed visit fee, then submit.'),
          ),
        );
      return;
    }
    if (!readyToSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Complete every required request item before submitting.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in as a driver so providers can receive your request.',
          ),
        ),
      );

      return;
    }

    setState(() {
      submitting = true;
    });
    try {
      final connections = await Connectivity().checkConnectivity();

      if (connections.every((result) => result == ConnectivityResult.none)) {
        await RequestDraftStore().save(widget.draft);

        await RequestDraftStore().setPendingSubmission(true);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are offline. Your draft is saved. Reconnect, review and submit when ready.',
            ),
          ),
        );

        return;
      }

      setState(() {
        submitting = true;
      });

      await draftStore.save(widget.draft);
      var submissionId = await draftStore.submissionId();
      if (submissionId == null) {
        submissionId = FirebaseFirestore.instance
            .collection('requests')
            .doc()
            .id;
        await draftStore.setSubmissionId(submissionId);
      }
      await draftStore.setPendingSubmission(true);
      final requestId = await RequestService()
          .createRequest(
            widget.draft,
            submissionId: submissionId,
            visitQuote: visitQuote,
          )
          .timeout(const Duration(seconds: 30));

      await RequestDraftStore().clear();

      if (!mounted) return;

      final servicePage = SearchingScreen(
        draft: widget.draft,
        requestId: requestId,
      );
      if (widget.compact) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => servicePage),
          (route) => route.isFirst,
        );
      } else {
        replace(context, servicePage);
      }
    } catch (error) {
      if (!mounted) return;

      final activeRequestExists = error.toString().contains(
        'Complete or cancel your active request',
      );

      final networkError =
          error is TimeoutException ||
          error is FirebaseException &&
              const [
                'unavailable',
                'deadline-exceeded',
                'network-request-failed',
              ].contains(error.code);

      if (networkError) {
        await RequestDraftStore().save(widget.draft);

        await RequestDraftStore().setPendingSubmission(true);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activeRequestExists
                ? 'Complete or cancel your current request before creating another.'
                : networkError
                ? 'Connection lost. Your draft is saved. Reconnect to check submission before retrying.'
                : _workflowError(
                    error,
                    'Unable to create the request. Please try again.',
                  ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: activeRequestExists
              ? SnackBarAction(
                  label: 'OPEN REQUEST',
                  textColor: Colors.white,
                  onPressed: () {
                    push(context, const HistoryScreen());
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  String partsPreferenceLabel(String value) => switch (value) {
    'budget' => 'Budget compatible',
    'branded' => 'Branded aftermarket',
    'genuine' => 'Genuine manufacturer parts',
    _ => 'Discuss options with provider',
  };

  BreakdownPhotoAnnotation? annotationFor(int index) {
    for (final annotation in widget.draft.photoAnnotations) {
      if (annotation.photoIndex == index) {
        return annotation;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    if (widget.compact) return buildCompactReview(context);

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Review Request',
          style: roadAssistTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  if (offline || connectionNotice != null) ...[
                    InlineMessage(
                      icon: offline
                          ? Icons.wifi_off_rounded
                          : Icons.sync_rounded,
                      text: offline
                          ? 'You are offline. Your draft is saved on this device. Connect before submitting.'
                          : connectionNotice!,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _RaReviewProgress(),

                  const SizedBox(height: 16),

                  const _RaReviewHero(),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Selected provider',
                    subtitle: 'Your request goes directly to this provider.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewProviderCard(
                    specificProvider: specificProvider,
                    providerName: widget.draft.provider,
                  ),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Request summary',
                    subtitle:
                        'Check the vehicle, problem and roadside location.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewSurface(
                    child: Column(
                      children: [
                        _RaReviewRow(
                          icon: Icons.car_repair_outlined,
                          label: 'Assistance',
                          value: widget.draft.issue,
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.priority_high_rounded,
                          label: 'Priority',
                          value: requestPriorityLabel(widget.draft.priority),
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Vehicle',
                          value:
                              '${widget.draft.modelYear} • ${widget.draft.vehicleType}',
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.pin_outlined,
                          label: 'Registration',
                          value: widget.draft.registration.toUpperCase(),
                        ),

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.location_on_outlined,
                          label: 'Breakdown location',
                          value: widget.draft.location,
                        ),

                        if (widget.draft.landmark.isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.signpost_outlined,
                            label: 'Landmark',
                            value: widget.draft.landmark,
                          ),
                        ],

                        if (widget.draft.description.trim().isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.description_outlined,
                            label: 'Symptoms',
                            value: widget.draft.description,
                          ),
                        ],

                        const _RaReviewDivider(),

                        _RaReviewRow(
                          icon: Icons.settings_outlined,
                          label: 'Parts preference',
                          value: partsPreferenceLabel(
                            widget.draft.partsPreference,
                          ),
                        ),

                        if (widget.draft.notes.trim().isNotEmpty) ...[
                          const _RaReviewDivider(),

                          _RaReviewRow(
                            icon: Icons.sticky_note_2_outlined,
                            label: 'Additional notes',
                            value: widget.draft.notes,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Photo evidence',
                    subtitle:
                        'Photos help your selected provider prepare for the visit.',
                  ),

                  const SizedBox(height: 11),

                  _buildEvidence(context),

                  const SizedBox(height: 26),

                  const _RaReviewHeading(
                    title: 'Pricing',
                    subtitle:
                        'No payment is confirmed when the request is submitted.',
                  ),

                  const SizedBox(height: 11),

                  _RaReviewSurface(
                    child: Column(
                      children: [
                        if (loadingVisitFee) const LinearProgressIndicator(),
                        if (visitFeeError != null) ...[
                          Text(visitFeeError!),
                          TextButton(
                            onPressed: loadVisitFee,
                            child: const Text('Retry visit fee'),
                          ),
                        ],
                        if (visitQuote != null)
                          _RaPricingPoint(
                            icon: Icons.route_outlined,
                            title: 'Visit fee: Rs. ${visitQuote!['visitFee']}',
                            message:
                                '${(visitQuote!['distanceKm'] as num).toStringAsFixed(2)} km estimated straight-line distance. First 1 km Rs. 100; each additional started km Rs. 20. This fee is fixed when you submit.',
                          ),
                        const SizedBox(height: 12),
                        const _RaPricingPoint(
                          icon: Icons.receipt_long_outlined,
                          title: 'One final bill after the work',
                          message:
                              'Inspection and labour appear in the final bill. Replacement parts and proposed extra work need your approval before they are done. Pay after service.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: raGold.withValues(alpha: .075),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          color: raGold,
                          size: 19,
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            'If there is immediate danger, contact emergency services before waiting for a roadside provider.',
                            style: roadAssistTextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _RaReviewBottomBar(
              ready:
                  readyToSubmit &&
                  !offline &&
                  visitQuote != null &&
                  !loadingVisitFee,
              submitting: submitting,
              offline: offline,
              checking: checkingSubmission,
              onSubmit: () {
                unawaited(submitRequest());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCompactReview(BuildContext context) => RaDriverScaffold(
    appBar: AppBar(
      title: const Text('Confirm your request'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: submitting ? null : () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (offline || connectionNotice != null)
                  InlineMessage(
                    icon: Icons.info_outline,
                    text: offline
                        ? 'Connect to submit. Your draft is saved.'
                        : connectionNotice!,
                  ),
                Text(
                  widget.draft.provider,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(widget.draft.issue),
                const SizedBox(height: 20),
                _RaReviewSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loadingVisitFee) const LinearProgressIndicator(),
                      if (visitFeeError != null) ...[
                        Text(visitFeeError!),
                        TextButton(
                          onPressed: loadVisitFee,
                          child: const Text('Retry visit fee'),
                        ),
                      ],
                      if (visitQuote != null) ...[
                        Text(
                          'Visit fee: Rs. ${visitQuote!['visitFee']}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(visitQuote!['distanceKm'] as num).toStringAsFixed(2)} km straight-line distance. First km Rs. 100, then Rs. 20 per additional started km.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'This confirms the visit only. Inspection and repair are billed after service. Parts or extra work requiring approval are agreed before they are done.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _RaReviewRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Vehicle',
                  value:
                      '${widget.draft.modelYear} ? ${widget.draft.registration}',
                ),
                const SizedBox(height: 12),
                _RaReviewRow(
                  icon: Icons.location_on_outlined,
                  label: 'Meet here',
                  value: widget.draft.location,
                ),
                if (widget.draft.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(widget.draft.description),
                  ),
                if (widget.draft.vehiclePhotoUrls.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Attached photos'),
                    children: [_buildEvidence(context)],
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Stay in a safe place while waiting. If you are in immediate danger, contact emergency services.',
                ),
              ],
            ),
          ),
          _RaReviewBottomBar(
            submitting: submitting,
            checking: checkingSubmission,
            offline: offline,
            ready:
                readyToSubmit &&
                !offline &&
                visitQuote != null &&
                !loadingVisitFee,
            onSubmit: () => unawaited(submitRequest()),
          ),
        ],
      ),
    ),
  );

  Widget _buildEvidence(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final photos = widget.draft.vehiclePhotoUrls;

    if (photos.isEmpty) {
      return _RaReviewSurface(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.photo_outlined, color: colors.onSurfaceVariant),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No photos added',
                    style: roadAssistTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Photo evidence is optional.',
                    style: roadAssistTextStyle(
                      fontSize: 12,
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

    return _RaReviewSurface(
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (context, index) {
            return const SizedBox(width: 8);
          },
          itemBuilder: (context, index) {
            final annotation = annotationFor(index);

            Widget image;

            try {
              image = Image.memory(
                base64Decode(photos[index]),
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              );
            } on FormatException {
              image = Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                color: colors.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              );
            }

            return SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: image,
                    ),
                  ),

                  if (annotation != null)
                    Positioned(
                      left: (annotation.markerX * 92)
                          .clamp(0.0, 85.0)
                          .toDouble(),
                      top: (annotation.markerY * 87)
                          .clamp(0.0, 78.0)
                          .toDouble(),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: colors.error,
                        size: 24,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 4),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RaReviewProgress extends StatelessWidget {
  const _RaReviewProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'STEP 4 OF 4',
                style: roadAssistTextStyle(
                  fontSize: 12,
                  letterSpacing: .8,
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Review',
              style: roadAssistTextStyle(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 5,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaReviewHero extends StatelessWidget {
  const _RaReviewHero();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B477D), Color(0xFF08645D)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to request help?',
                  style: roadAssistTextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Check your vehicle, location and assistance details before sending the request.',
                  style: roadAssistTextStyle(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 13,
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

class _RaReviewHeading extends StatelessWidget {
  const _RaReviewHeading({required this.title, required this.subtitle});

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
          style: roadAssistTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          style: roadAssistTextStyle(
            fontSize: 13,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaReviewProviderCard extends StatelessWidget {
  const _RaReviewProviderCard({
    required this.specificProvider,
    required this.providerName,
  });

  final bool specificProvider;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final title = specificProvider ? providerName : 'Choose a provider';

    return _RaReviewSurface(
      child: Row(
        children: [
          specificProvider
              ? ProfileInitials(name: title, radius: 25)
              : Container(
                  width: 50,
                  height: 50,
                  decoration: RaPremiumDecoration(
                    context,
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    color: colors.primary,
                  ),
                ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: roadAssistTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  specificProvider
                      ? 'Your request goes directly to this provider.'
                      : 'Go back and select an available provider before submitting.',
                  style: roadAssistTextStyle(
                    fontSize: 12,
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

class _RaReviewSurface extends StatelessWidget {
  const _RaReviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: RaPremiumDecoration(
        context,
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _RaReviewRow extends StatelessWidget {
  const _RaReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: roadAssistTextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: roadAssistTextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _RaReviewDivider extends StatelessWidget {
  const _RaReviewDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Divider(
      height: 1,
      indent: 28,
      color: colors.outlineVariant.withValues(alpha: .34),
    );
  }
}

class _RaPricingPoint extends StatelessWidget {
  const _RaPricingPoint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: roadAssistTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                message,
                style: roadAssistTextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaReviewBottomBar extends StatelessWidget {
  const _RaReviewBottomBar({
    required this.ready,
    required this.submitting,
    required this.onSubmit,
    this.offline = false,
    this.checking = false,
  });

  final bool offline;
  final bool checking;
  final bool ready;
  final bool submitting;

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: ready && !submitting ? onSubmit : null,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            checking
                ? 'Checking request status...'
                : offline
                ? 'Connect to submit'
                : submitting
                ? 'Sending request...'
                : ready
                ? 'Request Roadside Assistance'
                : 'Complete Request Details',
          ),
        ),
      ),
    );
  }
}
