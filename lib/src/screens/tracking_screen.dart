part of '../screens.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.draft, this.requestId});
  final RequestDraft draft;
  final String? requestId;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  int status = 0;
  LatLng providerPosition = MapMock.providerPoint;
  String providerName = 'Service Provider';
  String providerPhone = '';
  int estimatedCost = 0;
  bool cancelled = false;
  bool arrivalNeedsConfirmation = false;
  String arrivalLocationHint = '';
  bool completionPending = false;
  String completionNotes = '';
  List<String> completionPhotos = [];
  String? recoveryReason;
  bool hasProviderLocation = false;
  String? requestError;
  RoadRoute? roadRoute;
  bool routeLoading = false;
  int routeRequestVersion = 0;
  final statuses = const ['Accepted', 'En Route', 'Arrived', 'Completed'];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestListener;

  Future<void> confirmArrival() async {
    final reason = await _adminReason(
      context,
      'Confirm you met the provider. Explain any missing or inaccurate GPS.',
    );
    if (reason == null || !mounted || widget.requestId == null) return;
    try {
      await RequestService().confirmProviderArrival(widget.requestId!, reason);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> replaceDelayedProvider() async {
    final reason = await _adminReason(
      context,
      'Reason for replacing the provider',
    );
    if (reason == null || !mounted || widget.requestId == null) return;
    try {
      await RequestService().withdrawProvider(widget.requestId!, reason);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> refreshRoadRoute(LatLng origin) async {
    final version = ++routeRequestVersion;
    if (mounted) setState(() => routeLoading = true);
    try {
      final result = await const RouteService().fetchDrivingRoute(
        origin: origin,
        destination: LatLng(widget.draft.latitude, widget.draft.longitude),
      );
      if (!mounted || version != routeRequestVersion) return;
      setState(() {
        roadRoute = result;
        routeLoading = false;
      });
    } catch (_) {
      if (!mounted || version != routeRequestVersion) return;
      setState(() {
        routeLoading = false;
        requestError = 'Road route ETA is temporarily unavailable.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      requestListener = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final value = snapshot.data()?['status'] as String?;
              final data = snapshot.data();
              final latitude = (data?['providerLatitude'] as num?)?.toDouble();
              final longitude = (data?['providerLongitude'] as num?)
                  ?.toDouble();
              final updatedPosition = latitude != null && longitude != null
                  ? LatLng(latitude, longitude)
                  : null;
              final shouldRefreshRoute =
                  updatedPosition != null &&
                  (!hasProviderLocation ||
                      Geolocator.distanceBetween(
                            providerPosition.latitude,
                            providerPosition.longitude,
                            updatedPosition.latitude,
                            updatedPosition.longitude,
                          ) >=
                          20);
              final next = switch (value) {
                'accepted' => 0,
                'en_route' => 1,
                'arrived' => 2,
                'completed' => 3,
                _ => status,
              };
              if (mounted) {
                setState(() {
                  status = next;
                  cancelled = value == 'cancelled';
                  arrivalNeedsConfirmation =
                      data?['arrivalVerificationRequired'] == true &&
                      data?['arrivalConfirmedBy'] == null;
                  arrivalLocationHint = updatedPosition == null
                      ? 'Provider GPS is unavailable. Confirm only if you have met the provider.'
                      : 'Provider GPS is informational. Confirm only if the provider is physically with you.';
                  completionPending = data?['completionState'] == 'pending';
                  completionNotes = data?['serviceNotes'] as String? ?? '';
                  completionPhotos = (data?['servicePhotoData'] as List? ?? [])
                      .whereType<String>()
                      .toList();
                  recoveryReason = data?['cancellationReason'] as String?;
                  requestError = null;
                  providerName =
                      data?['providerName'] as String? ?? providerName;
                  providerPhone =
                      data?['providerPhone'] as String? ?? providerPhone;
                  estimatedCost =
                      (data?['estimatedCost'] as num?)?.toInt() ??
                      estimatedCost;
                  if (updatedPosition != null) {
                    providerPosition = updatedPosition;
                    hasProviderLocation = true;
                  }
                });
                if (shouldRefreshRoute) {
                  unawaited(refreshRoadRoute(updatedPosition));
                }
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  requestError = 'Live updates are temporarily unavailable.';
                });
              }
            },
          );
    } else {
      requestError = 'This request is not connected to live tracking.';
    }
  }

  @override
  void dispose() {
    requestListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Track Assistance'),
      actions: [
        if (widget.requestId != null)
          IconButton(
            tooltip: 'Invoice',
            icon: const Icon(Icons.receipt_long),
            onPressed: () =>
                push(context, InvoiceScreen(requestId: widget.requestId!)),
          ),
        IconButton(
          onPressed: () => push(context, const EmergencyScreen()),
          tooltip: 'Emergency contact',
          style: IconButton.styleFrom(
            backgroundColor: raDangerPale,
            foregroundColor: raDanger,
          ),
          icon: const Icon(Icons.sos_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                if (widget.requestId != null)
                  RepairQuotePanel(requestId: widget.requestId!),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RaRadius.md),
                      child: SizedBox(
                        height: 280,
                        child: MapMock(
                          position: LatLng(
                            widget.draft.latitude,
                            widget.draft.longitude,
                          ),
                          providerPosition: providerPosition,
                          routePoints: roadRoute?.points,
                          showProviders: hasProviderLocation,
                          showRoute: roadRoute != null,
                        ),
                      ),
                    ),
                    Positioned(
                      left: RaSpace.sm,
                      right: RaSpace.sm,
                      top: RaSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RaSpace.md,
                          vertical: RaSpace.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(RaRadius.sm),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0C285F),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_searching,
                              color: raBlue,
                              size: 20,
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              child: Text(
                                cancelled
                                    ? 'Request cancelled'
                                    : status == 3
                                    ? 'Assistance completed'
                                    : hasProviderLocation
                                    ? roadRoute == null
                                          ? 'Calculating road route...'
                                          : roadRoute!.trafficAware
                                          ? 'Live traffic route'
                                          : 'Fastest driving route'
                                    : 'Waiting for provider location',
                                style: RaText.title,
                              ),
                            ),
                            if (!cancelled && status < 3 && roadRoute != null)
                              Text(
                                '${roadRoute!.distanceKm.toStringAsFixed(1)} km · ${roadRoute!.durationMinutes} min',
                                style: RaText.caption.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (requestError != null && !routeLoading)
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: raDanger,
                                size: 19,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RaSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.md),
                    child: Row(
                      children: [
                        ProfileInitials(name: providerName, radius: 24),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(providerName, style: RaText.title),
                              const SizedBox(height: 2),
                              Text(
                                providerPhone.isEmpty
                                    ? 'RoadAssist Service Provider'
                                    : providerPhone,
                                style: RaText.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: providerPhone.isEmpty
                              ? null
                              : () => showCallPrompt(
                                  context,
                                  name: providerName,
                                  number: providerPhone,
                                ),
                          tooltip: 'Call',
                          icon: const Icon(Icons.call_outlined),
                        ),
                        const SizedBox(width: RaSpace.xs),
                        IconButton.filledTonal(
                          onPressed: widget.requestId == null
                              ? null
                              : () => push(
                                  context,
                                  ChatScreen(
                                    requestId: widget.requestId,
                                    peerName: providerName,
                                    peerPhone: providerPhone,
                                  ),
                                ),
                          tooltip: 'Chat',
                          icon: _UnreadChatIcon(
                            requestId: widget.requestId,
                            seenField: 'driverMessagesSeenAt',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                Text(
                  cancelled
                      ? 'Request cancelled'
                      : status == 0
                      ? 'Provider accepted your request'
                      : status == 1
                      ? 'Provider is on the way'
                      : status == 2
                      ? 'Provider has arrived'
                      : 'Assistance completed',
                  style: RaText.headline,
                ),
                if (requestError != null) ...[
                  const SizedBox(height: RaSpace.xs),
                  Text(
                    requestError!,
                    style: RaText.bodyMuted.copyWith(color: raDanger),
                  ),
                ],
                const SizedBox(height: RaSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: RaSpace.lg,
                    ),
                    child: StatusTimeline(statuses: statuses, current: status),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                InfoStrip(
                  icon: Icons.receipt_long_outlined,
                  title: 'Request ${widget.requestId ?? 'Not available'}',
                  value: '${widget.draft.issue} - Estimated Rs. $estimatedCost',
                ),
              ],
            ),
          ),
          if (cancelled && recoveryReason != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Provider unavailable: $recoveryReason. Choose another provider and approve a new price.',
              ),
            ),
          if (!cancelled && status == 0 && widget.requestId != null)
            TextButton(
              onPressed: replaceDelayedProvider,
              child: const Text(
                'Provider has not departed? Replace after 10 minutes',
              ),
            ),
          if (!cancelled && status == 2 && arrivalNeedsConfirmation)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(arrivalLocationHint),
                  FilledButton(
                    onPressed: confirmArrival,
                    child: const Text('Confirm provider has arrived'),
                  ),
                ],
              ),
            ),
          if (completionPending && widget.requestId != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Provider submitted completed work. Please review and confirm.',
                    style: RaText.title,
                  ),
                  Text(completionNotes),
                  RevisionEvidencePhotos(photos: completionPhotos),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await RequestService().confirmJobCompletion(
                          widget.requestId!,
                        );
                      } catch (error) {
                        if (context.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    },
                    child: const Text('Confirm work completed'),
                  ),
                  TextButton(
                    onPressed: () => push(
                      context,
                      DisputeScreen(requestId: widget.requestId!),
                    ),
                    child: const Text('Problem remains - report to admin'),
                  ),
                ],
              ),
            ),
          BottomAction(
            label: cancelled
                ? (recoveryReason == null
                      ? 'Back to Home'
                      : 'Find another provider')
                : widget.requestId != null && status < 3
                ? 'Waiting for provider update'
                : status == 3
                ? (recoveryReason == null
                      ? 'Back to Home'
                      : 'Find another provider')
                : 'Live tracking unavailable',
            enabled: cancelled || status == 3,
            onTap: () {
              if (cancelled && recoveryReason != null) {
                replace(
                  context,
                  ReviewScreen(draft: widget.draft.copyWith(provider: '')),
                );
              } else if (cancelled || status == 3) {
                replace(context, const DriverShell());
              }
            },
          ),
        ],
      ),
    ),
  );
}
