part of '../../screens.dart';

class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});
  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  bool offersOnly = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget _page(Map<String, dynamic> profile, Widget content) {
    final services = (profile['services'] as List? ?? const [])
        .whereType<String>()
        .toList();
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          RaProviderHeader(
            notifications: IconButton(
              tooltip: 'New requests',
              onPressed: () {
                setState(() => offersOnly = false);
                if (scroll.hasClients) {
                  scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Nearby requests',
            style: _providerText(context, size: 24, weight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => SegmentedButton<bool>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(value: false, label: Text('Available')),
                ButtonSegment(value: true, label: Text('Offers sent')),
              ],
              selected: {offersOnly},
              onSelectionChanged: (value) =>
                  setState(() => offersOnly = value.first),
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Theme.of(context).colorScheme.primary
                      : _providerSurface(context),
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textStyle: WidgetStatePropertyAll(
                  _providerText(context, size: 13, weight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Matches your services and service radius.',
            style: _providerText(context, size: 12, muted: true),
          ),
          const SizedBox(height: 18),
          if (services.isEmpty) ...[
            const RaProviderEmptyCard(
              icon: Icons.home_repair_service_outlined,
              title: 'Configure your services',
              message:
                  'Add the roadside services you provide to see matching requests.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openProviderProfile(context),
              child: const Text('Manage services'),
            ),
          ] else
            content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return RaProviderScaffold(
      body: uid == null
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.login_outlined,
                  title: 'Sign in required',
                  message:
                      'Sign in as a provider to view roadside assistance requests.',
                ),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AuthService().watchCurrentProfile(),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.hasError) {
                  return const Center(
                    child: InlineMessage(
                      icon: Icons.cloud_off_outlined,
                      text: 'Unable to load provider profile.',
                    ),
                  );
                }
                if (!profileSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile =
                    profileSnapshot.data?.data() ?? <String, dynamic>{};
                final services = (profile['services'] as List? ?? const [])
                    .whereType<String>()
                    .toList();
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('providerDirectory')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, directorySnapshot) {
                    if (directorySnapshot.hasError) {
                      return _page(
                        profile,
                        const InlineMessage(
                          icon: Icons.cloud_off_outlined,
                          text:
                              'Unable to load your availability. Please try again.',
                        ),
                      );
                    }
                    if (!directorySnapshot.hasData) {
                      return _page(profile, const LinearProgressIndicator());
                    }
                    final directory =
                        directorySnapshot.data?.data() ?? <String, dynamic>{};
                    if (!offersOnly &&
                        _providerAvailabilityStatus(directory) != 'Online') {
                      return _page(
                        profile,
                        RaProviderEmptyCard(
                          icon: Icons.notifications_none_rounded,
                          title: directory['online'] == true
                              ? 'Not available for requests yet'
                              : 'Go online to see matching requests',
                          message: _providerAvailabilityExplanation(directory),
                        ),
                      );
                    }
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: RequestService().watchOpenRequests(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _page(
                            profile,
                            const InlineMessage(
                              icon: Icons.cloud_off_outlined,
                              text: 'Unable to load matching requests.',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return _page(
                            profile,
                            const LinearProgressIndicator(),
                          );
                        }
                        final requests = snapshot.data!.docs
                            .where(
                              (request) => _requestMatchesProvider(
                                request.data(),
                                uid,
                                services: services,
                              ),
                            )
                            .toList();
                        requests.sort((a, b) {
                          final urgentA = isHighPriority(
                            a.data()['priority'] as String? ?? 'normal',
                          );
                          final urgentB = isHighPriority(
                            b.data()['priority'] as String? ?? 'normal',
                          );
                          if (urgentA != urgentB) return urgentA ? -1 : 1;
                          final timeA =
                              (a.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          final timeB =
                              (b.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          return timeB.compareTo(timeA);
                        });
                        return _page(
                          profile,
                          _RaProviderOffersList(
                            key: ValueKey(uid),
                            userId: uid,
                            requests: requests,
                            offersOnly: offersOnly,
                            directory: directory,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Listen only to this provider's quote documents; other providers' offers stay private.
class _RaProviderOffersList extends StatefulWidget {
  const _RaProviderOffersList({
    super.key,
    required this.userId,
    required this.requests,
    required this.offersOnly,
    required this.directory,
  });
  final String userId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> requests;
  final bool offersOnly;
  final Map<String, dynamic> directory;
  @override
  State<_RaProviderOffersList> createState() => _RaProviderOffersListState();
}

class _RaProviderOffersListState extends State<_RaProviderOffersList> {
  final subscriptions =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  final offers = <String, bool>{};
  final errors = <String>{};
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _RaProviderOffersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final ids = widget.requests.map((r) => r.id).toSet();
    for (final id
        in subscriptions.keys.where((id) => !ids.contains(id)).toList()) {
      subscriptions.remove(id)?.cancel();
      offers.remove(id);
      errors.remove(id);
    }
    for (final request in widget.requests) {
      if (subscriptions.containsKey(request.id)) continue;
      subscriptions[request.id] = request.reference
          .collection('quotes')
          .doc(widget.userId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted || !subscriptions.containsKey(request.id)) return;
              setState(() {
                offers[request.id] = snapshot.exists;
                errors.remove(request.id);
              });
            },
            onError: (_) {
              if (mounted && subscriptions.containsKey(request.id)) {
                setState(() => errors.add(request.id));
              }
            },
          );
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (errors.isNotEmpty) {
      return const InlineMessage(
        icon: Icons.cloud_off_outlined,
        text:
            'Unable to load offer status. Check your connection and try again.',
      );
    }
    if (offers.length < widget.requests.length) {
      return const LinearProgressIndicator();
    }
    final requests = widget.requests
        .where((request) => offers[request.id] == widget.offersOnly)
        .toList();
    if (requests.isEmpty) {
      return RaProviderEmptyCard(
        icon: widget.offersOnly
            ? Icons.request_quote_outlined
            : Icons.notifications_none_rounded,
        title: widget.offersOnly ? 'No pending offers' : 'No matching requests',
        message: widget.offersOnly
            ? 'Offers you send for open requests will appear here.'
            : 'New matching requests will appear here in real time.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < requests.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _RaProviderNotificationRequestCard(
            key: ValueKey(requests[i].id),
            request: requests[i],
            directory: widget.directory,
            offerSent: widget.offersOnly,
          ),
        ],
      ],
    );
  }
}

class _RaProviderNotificationRequestCard extends StatefulWidget {
  const _RaProviderNotificationRequestCard({
    super.key,
    required this.request,
    required this.directory,
    required this.offerSent,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final Map<String, dynamic> directory;
  final bool offerSent;
  @override
  State<_RaProviderNotificationRequestCard> createState() =>
      _RaProviderNotificationRequestCardState();
}

class _RaProviderNotificationRequestCardState
    extends State<_RaProviderNotificationRequestCard> {
  bool busy = false;
  Future<void> _dismiss() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await RequestService().rejectRequest(widget.request.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _workflowError(error, 'Unable to dismiss this request.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.request.data();
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final age = created == null ? null : DateTime.now().difference(created);
    final time = age == null
        ? 'Time unavailable'
        : age.isNegative || age.inMinutes < 1
        ? 'Just now'
        : age.inHours < 1
        ? '${age.inMinutes} min ago'
        : age.inHours < 24
        ? '${age.inHours} hr ago'
        : '${created!.day}/${created.month}/${created.year}';
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    final providerLat = (widget.directory['latitude'] as num?)?.toDouble();
    final providerLng = (widget.directory['longitude'] as num?)?.toDouble();
    final updated = (widget.directory['locationUpdatedAt'] as Timestamp?)
        ?.toDate();
    String? distance;
    if (lat != null &&
        lng != null &&
        providerLat != null &&
        providerLng != null &&
        ProviderAvailability.hasFreshLocation(updated, DateTime.now())) {
      final km =
          Geolocator.distanceBetween(lat, lng, providerLat, providerLng) / 1000;
      if (km.isFinite) distance = '${km.toStringAsFixed(1)} km away';
    }
    final priority = data['priority'] as String? ?? 'normal';
    return RaProviderRequestTile(
      driver: data['driverName'] as String? ?? 'Driver',
      issue: requestIssueLabel(data),
      location:
          data['locationLabel'] as String? ??
          data['location'] as String? ??
          'Location unavailable',
      time: time,
      distance: distance,
      priority: isHighPriority(priority)
          ? requestPriorityLabel(priority)
          : null,
      busy: busy,
      offerSent: widget.offerSent,
      onDismiss: _dismiss,
      onView: () => push(
        context,
        ProviderRequestDetailsScreen(requestId: widget.request.id, data: data),
      ),
    );
  }
}
