part of '../../screens.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  @override
  void initState() {
    super.initState();

    if (signedIn) {
      unawaited(AuthService().markNotificationsSeen());
    }
  }

  String message(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'searching';

    return switch (status) {
      'searching' => 'Searching for an available provider',
      'accepted' =>
        '${data['providerName'] ?? 'A provider'} accepted your request',
      'en_route' => 'Your provider is on the way',
      'arrived' =>
        data['completionState'] == 'pending'
            ? 'Completed work is waiting for your review'
            : 'Your provider has arrived',
      'completed' => 'Your assistance request is complete',
      'cancelled' =>
        data['cancellationReason'] == null
            ? 'This request was cancelled'
            : 'Your assigned provider became unavailable',
      _ => 'Request status updated',
    };
  }

  String subtitle(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';

    if (status == 'cancelled' && data['cancellationReason'] != null) {
      return '${data['cancellationReason']} • Open request for recovery options';
    }

    return requestIssueLabel(data);
  }

  IconData statusIcon(String status) {
    return switch (status) {
      'searching' => Icons.person_search_outlined,
      'accepted' => Icons.handshake_outlined,
      'en_route' => Icons.navigation_outlined,
      'arrived' => Icons.location_on_outlined,
      'completed' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.notifications_active_outlined,
    };
  }

  Color statusTone(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;

    return switch (status) {
      'completed' => raSuccess,
      'cancelled' => colors.error,
      'searching' => raGold,
      _ => colors.primary,
    };
  }

  void openRequest(QueryDocumentSnapshot<Map<String, dynamic>> request) {
    final data = request.data();

    final status = data['status'] as String? ?? 'searching';

    final draft = requestDraftFromData(data);

    if (status == 'searching') {
      push(context, SearchingScreen(draft: draft, requestId: request.id));

      return;
    }

    if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
      push(context, TrackingScreen(draft: draft, requestId: request.id));

      return;
    }

    push(
      context,
      RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message: 'Sign in as a driver to view request notifications.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService().watchDriverRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load updates',
                      message: 'Check your connection and try again.',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data!.docs.toList();

                requests.sort((first, second) {
                  final firstTime =
                      first.data()['updatedAt'] as Timestamp? ??
                      first.data()['createdAt'] as Timestamp?;

                  final secondTime =
                      second.data()['updatedAt'] as Timestamp? ??
                      second.data()['createdAt'] as Timestamp?;

                  if (firstTime == null && secondTime == null) {
                    return 0;
                  }

                  if (firstTime == null) {
                    return 1;
                  }

                  if (secondTime == null) {
                    return -1;
                  }

                  return secondTime.compareTo(firstTime);
                });

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    _RaNotificationUpdatesHero(count: requests.length),

                    const SizedBox(height: 15),

                    Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF0D2237)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .45),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const _ChatInbox(isProvider: false, preview: true),
                    ),

                    const SizedBox(height: 23),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Request updates',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${requests.length}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (requests.isEmpty)
                      const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message:
                            'Request status updates will appear here in real time.',
                      )
                    else
                      for (var index = 0; index < requests.length; index++) ...[
                        _RaDriverNotificationCard(
                          request: requests[index],
                          message: message(requests[index].data()),
                          subtitle: subtitle(requests[index].data()),
                          icon: statusIcon(
                            requests[index].data()['status'] as String? ?? '',
                          ),
                          tone: statusTone(
                            context,
                            requests[index].data()['status'] as String? ?? '',
                          ),
                          onTap: () {
                            openRequest(requests[index]);
                          },
                        ),
                        if (index != requests.length - 1)
                          const SizedBox(height: 8),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

class _RaNotificationUpdatesHero extends StatelessWidget {
  const _RaNotificationUpdatesHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0A497F), Color(0xFF075A68)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RoadAssist updates',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Important request activity will appear here.'
                      : '$count ${count == 1 ? 'request' : 'requests'} currently available in your update history.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
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

class _RaDriverNotificationCard extends StatelessWidget {
  const _RaDriverNotificationCard({
    required this.request,
    required this.message,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  final String message;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  String? timeLabel() {
    final data = request.data();

    final timestamp =
        data['updatedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;

    if (timestamp == null) {
      return null;
    }

    final value = timestamp.toDate().toLocal();

    final difference = DateTime.now().difference(value);

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    return '${value.day}/${value.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final time = timeLabel();

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(width: 7),
                          Text(
                            time,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Open request',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
