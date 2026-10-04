part of '../screens.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.draft});
  final RequestDraft draft;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool submitting = false;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  @override
  void initState() {
    super.initState();
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if (!mounted ||
          results.every((result) => result == ConnectivityResult.none)) {
        return;
      }
      if (await RequestDraftStore().hasPendingSubmission() && mounted) {
        await submitRequest(autoRetry: true);
      }
    });
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    super.dispose();
  }

  String formatPrice(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return 'Rs. $digits';
    return 'Rs. ${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}';
  }

  Future<void> submitRequest({bool autoRetry = false}) async {
    if (submitting) return;
    final readyToSubmit =
        widget.draft.modelYear.isNotEmpty &&
        widget.draft.registration.isNotEmpty &&
        !widget.draft.location.startsWith('Select current GPS') &&
        widget.draft.preferredProviderId.isNotEmpty;
    if (!readyToSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete every required checklist item before submitting.',
          ),
          backgroundColor: raDanger,
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
    final connections = await Connectivity().checkConnectivity();
    if (connections.every((result) => result == ConnectivityResult.none)) {
      await RequestDraftStore().save(widget.draft);
      await RequestDraftStore().setPendingSubmission(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Request saved and will retry when connected.',
          ),
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final requestId = await RequestService().createRequest(widget.draft);
      await RequestDraftStore().clear();
      if (!mounted) return;
      await showSafetyChecklist();
      if (!mounted) return;
      replace(
        context,
        SearchingScreen(draft: widget.draft, requestId: requestId),
      );
    } catch (error) {
      if (!mounted) return;
      final activeRequestExists = error.toString().contains(
        'Complete or cancel your active request',
      );
      final networkError =
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
                ? 'Connection lost. Request saved and will retry automatically.'
                : 'Unable to create the request. Please try again.',
          ),
          backgroundColor: raDanger,
          action: activeRequestExists
              ? SnackBarAction(
                  label: 'OPEN REQUEST',
                  textColor: Colors.white,
                  onPressed: () => push(context, const HistoryScreen()),
                )
              : null,
        ),
      );
      setState(() => submitting = false);
    }
  }

  Future<void> showSafetyChecklist() async {
    var vehicleSafe = false;
    var hazardsOn = false;
    var passengersSafe = false;
    var emergencyRequired = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.health_and_safety_outlined, color: raBlue),
          title: const Text('Safety confirmation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: vehicleSafe,
                  onChanged: (value) =>
                      setDialogState(() => vehicleSafe = value ?? false),
                  title: const Text('Vehicle moved to a safe place'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: hazardsOn,
                  onChanged: (value) =>
                      setDialogState(() => hazardsOn = value ?? false),
                  title: const Text('Hazard lights are on'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: passengersSafe,
                  onChanged: (value) =>
                      setDialogState(() => passengersSafe = value ?? false),
                  title: const Text('Passengers are safe'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: emergencyRequired,
                  onChanged: (value) =>
                      setDialogState(() => emergencyRequired = value ?? false),
                  title: const Text('Emergency service is required'),
                  subtitle: const Text('Call 119 for immediate danger'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            if (emergencyRequired)
              TextButton.icon(
                onPressed: () => showCallPrompt(
                  dialogContext,
                  name: 'Emergency Services',
                  number: '119',
                ),
                icon: const Icon(Icons.call, color: raDanger),
                label: const Text('Call 119'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue Tracking'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review Request')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                const StepEyebrow(step: 4, of: 4),
                const SizedBox(height: RaSpace.lg),
                const Text('ASSIGNED PROVIDER', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Row(
                      children: [
                        ProfileInitials(
                          name: widget.draft.provider,
                          radius: 25,
                        ),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.draft.provider, style: RaText.title),
                              const SizedBox(height: 2),
                              const Text(
                                'RoadAssist certified provider',
                                style: RaText.caption,
                              ),
                              const SizedBox(height: RaSpace.xs),
                              const StatusPill(
                                label: 'Available now',
                                tone: RaTone.success,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: raGoldPale,
                            borderRadius: BorderRadius.circular(RaRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: raGold, size: 14),
                              SizedBox(width: 2),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: raGold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const Text('REQUEST DETAILS', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        SummaryRow('Assistance Type', widget.draft.issue),
                        const Divider(),
                        SummaryRow(
                          'Priority',
                          requestPriorityLabel(widget.draft.priority),
                        ),
                        const Divider(),
                        SummaryRow(
                          'Vehicle',
                          '${widget.draft.modelYear} (${widget.draft.vehicleType})',
                        ),
                        const Divider(),
                        SummaryRow(
                          'Registration',
                          widget.draft.registration.toUpperCase(),
                        ),
                        const Divider(),
                        SummaryRow('Pickup Location', widget.draft.location),
                        if (widget.draft.landmark.isNotEmpty) ...[
                          const Divider(),
                          SummaryRow('Nearby Landmark', widget.draft.landmark),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const Text('READY TO SUBMIT', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                _RequestValidationChecklist(draft: widget.draft),
                if (widget.draft.vehiclePhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: RaSpace.xl),
                  const Text('PHOTO EVIDENCE', style: RaText.eyebrow),
                  const SizedBox(height: RaSpace.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.draft.vehiclePhotoUrls.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: RaSpace.sm),
                              itemBuilder: (context, index) {
                                final annotation = widget.draft.photoAnnotations
                                    .where((item) => item.photoIndex == index)
                                    .firstOrNull;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    RaRadius.sm,
                                  ),
                                  child: Stack(
                                    children: [
                                      Image.memory(
                                        base64Decode(
                                          widget.draft.vehiclePhotoUrls[index],
                                        ),
                                        width: 92,
                                        height: 92,
                                        fit: BoxFit.cover,
                                      ),
                                      if (annotation != null)
                                        Positioned(
                                          left: annotation.markerX * 76,
                                          top: annotation.markerY * 70,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: raDanger,
                                            size: 22,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          for (final annotation
                              in widget.draft.photoAnnotations)
                            if (annotation.note.isNotEmpty) ...[
                              const SizedBox(height: RaSpace.sm),
                              Text(
                                'Photo ${annotation.photoIndex + 1}: ${annotation.note}',
                                style: RaText.bodyMuted,
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: RaSpace.xl),
                const Text('PAYMENT SUMMARY', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        SummaryRow(
                          'Initial Service Estimate',
                          formatPrice(widget.draft.serviceFee),
                        ),
                        SummaryRow(
                          'Initial Dispatch Estimate',
                          formatPrice(widget.draft.dispatchFee),
                        ),
                        const Divider(),
                        SummaryRow(
                          'Estimated Total',
                          formatPrice(widget.draft.estimatedCost),
                          strong: true,
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(RaSpace.sm),
                          decoration: BoxDecoration(
                            color: raSuccessPale,
                            borderRadius: BorderRadius.circular(RaRadius.sm),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: raSuccess,
                                size: 17,
                              ),
                              SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: Text(
                                  'This is a system estimate. The provider reviews the issue and distance, then submits an itemised quote before accepting.',
                                  style: TextStyle(
                                    color: raSuccess,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                const InlineMessage(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Secure chat and calling become available after a provider accepts with a quote. Service, travel and extra charges will be shown separately.',
                ),
              ],
            ),
          ),
          BottomAction(
            label: submitting
                ? 'Submitting Request...'
                : 'Confirm Assistance Request',
            enabled: !submitting,
            onTap: submitRequest,
          ),
        ],
      ),
    ),
  );
}
