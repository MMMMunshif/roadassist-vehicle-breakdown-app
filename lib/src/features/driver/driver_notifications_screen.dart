part of '../../screens.dart';

class DriverNotificationsScreen
    extends StatefulWidget {
  const DriverNotificationsScreen({
    super.key,
  });

  @override
  State<DriverNotificationsScreen>
      createState() =>
          _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState
    extends State<DriverNotificationsScreen> {
  @override
  void initState() {
    super.initState();

    if (signedIn) {
      AuthService()
          .markNotificationsSeen();
    }
  }

  String _message(
    Map<String, dynamic> data,
  ) {
    final status =
        data['status'] as String? ??
            'searching';

    return switch (status) {
      'searching' =>
        'Searching for an available provider',
      'accepted' =>
        '${data['providerName'] ?? 'A provider'} accepted your request',
      'en_route' =>
        'Your provider is on the way',
      'arrived' =>
        data['completionState'] ==
                'pending'
            ? 'Completed work needs your review'
            : 'Your provider has arrived',
      'completed' =>
        'Your assistance request is complete',
      'cancelled' =>
        data['cancellationReason'] == null
            ? 'This request was cancelled'
            : 'Your assigned provider became unavailable',
      _ => 'Request status updated',
    };
  }

  String _subtitle(
    Map<String, dynamic> data,
  ) {
    final status =
        data['status'] as String? ?? '';

    if (status == 'cancelled' &&
        data['cancellationReason'] !=
            null) {
      return '${data['cancellationReason']} • Open request for recovery options';
    }

    return requestIssueLabel(data);
  }

  IconData _icon(String status) {
    return switch (status) {
      'searching' =>
        Icons.person_search_outlined,
      'accepted' =>
        Icons.handshake_outlined,
      'en_route' =>
        Icons.navigation_outlined,
      'arrived' =>
        Icons.location_on_outlined,
      'completed' =>
        Icons.check_circle_outline_rounded,
      'cancelled' =>
        Icons.cancel_outlined,
      _ =>
        Icons.notifications_active_outlined,
    };
  }

  Color _tone(
    BuildContext context,
    String status,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return switch (status) {
      'completed' => raSuccess,
      'arrived' => raSuccess,
      'cancelled' => colors.error,
      'en_route' =>
        const Color(0xFF167DE4),
      _ => colors.primary,
    };
  }

  void _openRequest(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        request,
  ) {
    final data = request.data();

    final status =
        data['status'] as String? ??
            'searching';

    final draft =
        requestDraftFromData(data);

    if (status == 'searching') {
      push(
        context,
        SearchingScreen(
          draft: draft,
          requestId: request.id,
        ),
      );
      return;
    }

    if (const [
      'accepted',
      'en_route',
      'arrived',
    ].contains(status)) {
      push(
        context,
        TrackingScreen(
          draft: draft,
          requestId: request.id,
        ),
      );
      return;
    }

    push(
      context,
      RealtimeDriverRequestDetailsScreen(
        requestId: request.id,
        data: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
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
                    'Sign in as a driver to view request notifications.',
              ),
            )
          : StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
              stream: RequestService()
                  .watchDriverRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon:
                        Icons.cloud_off_outlined,
                    title:
                        'Unable to load updates',
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

                final requests =
                    [...snapshot.data!.docs];

                requests.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();

                  final aTime =
                      (aData['updatedAt']
                                  as Timestamp?) ??
                          (aData['createdAt']
                              as Timestamp?);

                  final bTime =
                      (bData['updatedAt']
                                  as Timestamp?) ??
                          (bData['createdAt']
                              as Timestamp?);

                  if (aTime == null &&
                      bTime == null) {
                    return 0;
                  }

                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });

                return CustomScrollView(
                  physics:
                      const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        18,
                        10,
                        18,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            _DriverNotificationIntro(
                          count:
                              requests.length,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 14,
                      ),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child: Container(
                          decoration:
                              BoxDecoration(
                            color:
                                colors.surface,
                            borderRadius:
                                BorderRadius
                                    .circular(21),
                            border: Border.all(
                              color: colors
                                  .outlineVariant
                                  .withValues(
                                alpha: .50,
                              ),
                            ),
                          ),
                          clipBehavior:
                              Clip.antiAlias,
                          child:
                              const _ChatInbox(
                            isProvider: false,
                            preview: true,
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 26,
                      ),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Request updates',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  letterSpacing:
                                      -.35,
                                  color: colors
                                      .onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '${requests.length}',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                color: colors
                                    .onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 11,
                      ),
                    ),

                    if (requests.isEmpty)
                      const SliverPadding(
                        padding:
                            EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          30,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child: EmptyState(
                            icon: Icons
                                .notifications_none_rounded,
                            title:
                                'No notifications yet',
                            message:
                                'Request status updates will appear here in real time.',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          32,
                        ),
                        sliver:
                            SliverList.separated(
                          itemCount:
                              requests.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 9,
                          ),
                          itemBuilder:
                              (context, index) {
                            final request =
                                requests[index];

                            final status =
                                request.data()[
                                            'status']
                                        as String? ??
                                    '';

                            return _PremiumDriverNotificationCard(
                              request:
                                  request,
                              message:
                                  _message(
                                request.data(),
                              ),
                              subtitle:
                                  _subtitle(
                                request.data(),
                              ),
                              icon: _icon(
                                status,
                              ),
                              tone: _tone(
                                context,
                                status,
                              ),
                              onTap: () {
                                _openRequest(
                                  context,
                                  request,
                                );
                              },
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

class _DriverNotificationIntro
    extends StatelessWidget {
  const _DriverNotificationIntro({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.primary
            .withValues(alpha: .08),
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: colors.primary
              .withValues(alpha: .14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .12),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              Icons
                  .notifications_active_outlined,
              color: colors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay up to date',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'RoadAssist will show important request and message updates here.'
                      : '$count request ${count == 1 ? 'update is' : 'updates are'} available in your activity history.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    height: 1.45,
                    color: colors
                        .onSurfaceVariant,
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

class _PremiumDriverNotificationCard
    extends StatelessWidget {
  const _PremiumDriverNotificationCard({
    required this.request,
    required this.message,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final QueryDocumentSnapshot<
          Map<String, dynamic>>
      request;

  final String message;
  final String subtitle;

  final IconData icon;
  final Color tone;

  final VoidCallback onTap;

  String? _timeLabel() {
    final data = request.data();

    final timestamp =
        (data['updatedAt']
                    as Timestamp?) ??
            (data['createdAt']
                as Timestamp?);

    if (timestamp == null) return null;

    final value =
        timestamp.toDate().toLocal();

    final difference =
        DateTime.now().difference(value);

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${value.day}/${value.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    final time = _timeLabel();

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(19),
            border: Border.all(
              color: colors.outlineVariant
                  .withValues(alpha: .48),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tone.withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color: colors
                                  .onSurface,
                            ),
                          ),
                        ),

                        if (time != null) ...[
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            time,
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 9,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        height: 1.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Row(
                      children: [
                        Text(
                          'Open request',
                          style: GoogleFonts
                              .plusJakartaSans(
                            color:
                                colors.primary,
                            fontSize: 9.5,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Icon(
                          Icons
                              .arrow_forward_rounded,
                          size: 14,
                          color:
                              colors.primary,
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