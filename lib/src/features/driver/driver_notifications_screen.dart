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
        data['status']
                as String? ??
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
            ? 'Completed work is waiting for your review'
            : 'Your provider has arrived',
      'completed' =>
        'Your assistance request is complete',
      'cancelled' =>
        data['cancellationReason'] ==
                null
            ? 'This request was cancelled'
            : 'Your assigned provider became unavailable',
      _ =>
        'Request status updated',
    };
  }

  String _subtitle(
    Map<String, dynamic> data,
  ) {
    final status =
        data['status']
                as String? ??
            '';

    if (status == 'cancelled' &&
        data['cancellationReason'] !=
            null) {
      return '${data['cancellationReason']} • Open request for recovery options';
    }

    return requestIssueLabel(
      data,
    );
  }

  IconData _icon(
    String status,
  ) {
    return switch (status) {
      'searching' =>
        Icons
            .person_search_outlined,
      'accepted' =>
        Icons.handshake_outlined,
      'en_route' =>
        Icons
            .navigation_outlined,
      'arrived' =>
        Icons
            .location_on_outlined,
      'completed' =>
        Icons
            .check_circle_outline_rounded,
      'cancelled' =>
        Icons
            .cancel_outlined,
      _ =>
        Icons
            .notifications_active_outlined,
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
      'cancelled' =>
        colors.error,
      _ => colors.primary,
    };
  }

  void _openRequest(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        request,
  ) {
    final data =
        request.data();

    final status =
        data['status']
                as String? ??
            'searching';

    final draft =
        requestDraftFromData(
      data,
    );

    if (status == 'searching') {
      push(
        context,
        SearchingScreen(
          draft: draft,
          requestId:
              request.id,
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
          requestId:
              request.id,
        ),
      );
      return;
    }

    push(
      context,
      RealtimeDriverRequestDetailsScreen(
        requestId:
            request.id,
        data: data,
      ),
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
          'Notifications',
        ),
      ),

      body: !signedIn
          ? const Padding(
              padding:
                  EdgeInsets.all(
                RaSpace.lg,
              ),
              child: EmptyState(
                icon: Icons
                    .login_outlined,
                title:
                    'Sign in required',
                message:
                    'Sign in as a driver to view request notifications.',
              ),
            )
          : Column(
              children: [
                Container(
                  margin:
                      const EdgeInsets
                          .fromLTRB(
                    RaSpace.lg,
                    RaSpace.md,
                    RaSpace.lg,
                    0,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        colors.surface,
                    borderRadius:
                        BorderRadius
                            .circular(
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
                  clipBehavior:
                      Clip.antiAlias,
                  child:
                      const _ChatInbox(
                    isProvider:
                        false,
                    preview: true,
                  ),
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>(
                    stream:
                        RequestService()
                            .watchDriverRequests(),
                    builder: (
                      context,
                      snapshot,
                    ) {
                      if (snapshot
                          .hasError) {
                        return const EmptyState(
                          icon: Icons
                              .cloud_off_outlined,
                          title:
                              'Unable to load updates',
                          message:
                              'Check your connection and try again.',
                        );
                      }

                      if (!snapshot
                          .hasData) {
                        return const Center(
                          child:
                              CircularProgressIndicator(),
                        );
                      }

                      final requests =
                          snapshot
                              .data!.docs
                              .toList();

                      if (requests
                          .isEmpty) {
                        return const EmptyState(
                          icon: Icons
                              .notifications_none_rounded,
                          title:
                              'No notifications yet',
                          message:
                              'Request status updates will appear here in real time.',
                        );
                      }

                      return ListView(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          RaSpace.lg,
                          0,
                          RaSpace.lg,
                          RaSpace.xxl,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Request updates',
                                  style: theme
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                              ),
                              Text(
                                '${requests.length}',
                                style: theme
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                  color: colors
                                      .onSurfaceVariant,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height:
                                RaSpace.md,
                          ),

                          for (var index =
                                  0;
                              index <
                                  requests
                                      .length;
                              index++) ...[
                            _DriverNotificationCard(
                              request:
                                  requests[
                                      index],
                              message:
                                  _message(
                                requests[index]
                                    .data(),
                              ),
                              subtitle:
                                  _subtitle(
                                requests[index]
                                    .data(),
                              ),
                              icon:
                                  _icon(
                                requests[index]
                                        .data()[
                                    'status'] as String? ??
                                    '',
                              ),
                              tone:
                                  _tone(
                                context,
                                requests[index]
                                        .data()[
                                    'status'] as String? ??
                                    '',
                              ),
                              onTap: () =>
                                  _openRequest(
                                context,
                                requests[
                                    index],
                              ),
                            ),
                            if (index !=
                                requests
                                        .length -
                                    1)
                              const SizedBox(
                                height:
                                    RaSpace
                                        .sm,
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _DriverNotificationCard
    extends StatelessWidget {
  const _DriverNotificationCard({
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
    final data =
        request.data();

    final timestamp =
        (data['updatedAt']
                    as Timestamp?) ??
            (data['createdAt']
                as Timestamp?);

    if (timestamp == null) {
      return null;
    }

    final value =
        timestamp.toDate().toLocal();

    final now =
        DateTime.now();

    final difference =
        now.difference(value);

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    return '${value.day}/${value.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final time =
        _timeLabel();

    return Material(
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            RaSpace.lg,
          ),
          decoration: BoxDecoration(
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
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
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
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: theme
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w900,
                              height:
                                  1.3,
                            ),
                          ),
                        ),
                        if (time !=
                            null) ...[
                          const SizedBox(
                            width:
                                RaSpace
                                    .sm,
                          ),
                          Text(
                            time,
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height:
                          RaSpace.sm,
                    ),

                    Row(
                      children: [
                        Text(
                          'Open request',
                          style: theme
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: colors
                                .primary,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        Icon(
                          Icons
                              .arrow_forward_rounded,
                          color: colors
                              .primary,
                          size: 15,
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