part of '../../screens.dart';

class ProviderNotificationsScreen extends StatelessWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Assistance Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a provider to view roadside assistance requests.',
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AuthService().watchCurrentProfile(),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load provider profile',
                      message:
                          'Check your connection and try again.',
                    ),
                  );
                }

                if (!profileSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final profile =
                    profileSnapshot.data?.data() ??
                    <String, dynamic>{};

                final services =
                    (profile['services'] as List<dynamic>? ??
                            const [])
                        .whereType<String>()
                        .where(
                          (service) =>
                              service.trim().isNotEmpty,
                        )
                        .toList();

                return Column(
                  children: [
                    const _ChatInbox(
                      isProvider: true,
                      preview: true,
                    ),

                    Expanded(
                      child: services.isEmpty
                          ? _RaProviderNotificationsNoServices()
                          : StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                              stream: RequestService()
                                  .watchOpenRequests(),
                              builder: (
                                context,
                                snapshot,
                              ) {
                                if (snapshot.hasError) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: EmptyState(
                                      icon: Icons
                                          .cloud_off_outlined,
                                      title:
                                          'Unable to load requests',
                                      message:
                                          'Check your connection and try again.',
                                    ),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Center(
                                    child:
                                        CircularProgressIndicator(),
                                  );
                                }

                                final userId = FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.uid;

                                if (userId == null) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.all(20),
                                    child: EmptyState(
                                      icon: Icons.login_outlined,
                                      title:
                                          'Session unavailable',
                                      message:
                                          'Sign in again to continue.',
                                    ),
                                  );
                                }

                                final requests =
                                    snapshot.data!.docs.where(
                                  (request) {
                                    return _requestMatchesProvider(
                                      request.data(),
                                      userId,
                                      services: services,
                                    );
                                  },
                                ).toList();

                                requests.sort(
                                  (a, b) {
                                    final aPriority =
                                        isHighPriority(
                                      a.data()['priority']
                                              as String? ??
                                          'normal',
                                    );

                                    final bPriority =
                                        isHighPriority(
                                      b.data()['priority']
                                              as String? ??
                                          'normal',
                                    );

                                    if (aPriority != bPriority) {
                                      return aPriority ? -1 : 1;
                                    }

                                    final aTime =
                                        (a.data()['createdAt']
                                                as Timestamp?)
                                            ?.toDate();

                                    final bTime =
                                        (b.data()['createdAt']
                                                as Timestamp?)
                                            ?.toDate();

                                    if (aTime == null &&
                                        bTime == null) {
                                      return 0;
                                    }

                                    if (aTime == null) return 1;
                                    if (bTime == null) return -1;

                                    return bTime.compareTo(aTime);
                                  },
                                );

                                if (requests.isEmpty) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.all(20),
                                    child: EmptyState(
                                      icon: Icons
                                          .notifications_none_rounded,
                                      title:
                                          'No matching requests',
                                      message:
                                          'New roadside requests that match your configured services will appear here in real time.',
                                    ),
                                  );
                                }

                                return ListView(
                                  physics:
                                      const BouncingScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(
                                    18,
                                    14,
                                    18,
                                    32,
                                  ),
                                  children: [
                                    _RaProviderNotificationsHeader(
                                      count: requests.length,
                                      services: services,
                                    ),

                                    const SizedBox(height: 18),

                                    for (var index = 0;
                                        index < requests.length;
                                        index++) ...[
                                      if (index > 0)
                                        const SizedBox(
                                          height: 10,
                                        ),

                                      _RaProviderNotificationRequestCard(
                                        request: requests[index],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _RaProviderNotificationsNoServices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EmptyState(
          icon: Icons.home_repair_service_outlined,
          title: 'Configure your services',
          message:
              'Add the roadside services you provide before matching assistance requests can be shown.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            push(
              context,
              const ProviderProfileScreen(),
            );
          },
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Manage Services'),
        ),
      ],
    );
  }
}

class _RaProviderNotificationsHeader extends StatelessWidget {
  const _RaProviderNotificationsHeader({
    required this.count,
    required this.services,
  });

  final int count;
  final List<String> services;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: .14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count matching ${count == 1 ? 'request' : 'requests'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filtered using your current provider services. Open a request before submitting an offer.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final service in services)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.outlineVariant
                                .withValues(alpha: .5),
                          ),
                        ),
                        child: Text(
                          service,
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderNotificationRequestCard
    extends StatefulWidget {
  const _RaProviderNotificationRequestCard({
    required this.request,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>>
      request;

  @override
  State<_RaProviderNotificationRequestCard> createState() =>
      _RaProviderNotificationRequestCardState();
}

class _RaProviderNotificationRequestCardState
    extends State<_RaProviderNotificationRequestCard> {
  bool busy = false;

  Map<String, dynamic> get data =>
      widget.request.data();

  String _dateLabel() {
    final timestamp =
        data['createdAt'] as Timestamp?;

    if (timestamp == null) {
      return 'Time unavailable';
    }

    final value =
        timestamp.toDate().toLocal();

    final now = DateTime.now();

    final difference =
        now.difference(value);

    if (!difference.isNegative &&
        difference.inMinutes < 1) {
      return 'Just now';
    }

    if (!difference.isNegative &&
        difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }

    if (!difference.isNegative &&
        difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _locationLabel() {
    return data['locationLabel'] as String? ??
        data['location'] as String? ??
        'Location unavailable';
  }

  String _vehicleLabel() {
    return [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ]
        .where(
          (value) => value.trim().isNotEmpty,
        )
        .join(' • ');
  }

  Future<void> _dismiss() async {
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      await RequestService().rejectRequest(
        widget.request.id,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to dismiss this request.',
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

  Future<void> _reviewAndQuote() async {
    if (busy) return;

    push(
      context,
      ProviderRequestDetailsScreen(
        requestId: widget.request.id,
        data: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final driver =
        data['driverName'] as String? ?? 'Driver';

    final priority =
        data['priority'] as String? ?? 'normal';

    final highPriority =
        isHighPriority(priority);

    final vehicle =
        _vehicleLabel();

    final workflowVersion =
        data['workflowVersion'];

    final legacyPrice =
        (data['estimatedCost'] as num?)?.toInt();

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: highPriority
              ? raGold.withValues(alpha: .45)
              : colors.outlineVariant
                  .withValues(alpha: .45),
          width: highPriority ? 1.25 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _reviewAndQuote,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProfileInitials(
                    name: driver,
                    radius: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _dateLabel(),
                          style:
                              GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            color:
                                colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: highPriority
                        ? requestPriorityLabel(
                            priority,
                          )
                        : 'New',
                    tone: highPriority
                        ? RaTone.warning
                        : RaTone.info,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                requestIssueLabel(data),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.25,
                ),
              ),

              const SizedBox(height: 10),

              _RaProviderNotificationMeta(
                icon: Icons.location_on_outlined,
                text: _locationLabel(),
              ),

              if (vehicle.isNotEmpty)
                _RaProviderNotificationMeta(
                  icon:
                      Icons.directions_car_outlined,
                  text: vehicle,
                ),

              _RaProviderNotificationMeta(
                icon:
                    Icons.request_quote_outlined,
                text: workflowVersion == 2
                    ? 'Provider offer required'
                    : legacyPrice == null
                        ? 'Price unavailable'
                        : 'Estimated Rs. $legacyPrice',
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          busy ? null : _dismiss,
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : _reviewAndQuote,
                      icon: const Icon(
                        Icons
                            .arrow_forward_rounded,
                      ),
                      label: const Text(
                        'Review Request',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaProviderNotificationMeta
    extends StatelessWidget {
  const _RaProviderNotificationMeta({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: colors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8.7,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}