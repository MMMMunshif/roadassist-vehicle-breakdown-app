part of '../../screens.dart';

class _ChatInboxScreen extends StatefulWidget {
  const _ChatInboxScreen({
    required this.isProvider,
  });

  final bool isProvider;

  @override
  State<_ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<_ChatInboxScreen> {
  ChatInboxController? inbox;
  final searchController = TextEditingController();

  bool unreadOnly = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();

    if (signedIn) {
      inbox = ChatInboxController(
        isProvider: widget.isProvider,
      );
    }

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchQuery =
            searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    inbox?.dispose();
    super.dispose();
  }

  String peerNameFor(
    Map<String, dynamic> job,
  ) {
    return job[
                widget.isProvider
                    ? 'driverName'
                    : 'providerName']
            as String? ??
        (widget.isProvider
            ? 'Driver'
            : 'Service Provider');
  }

  String peerPhoneFor(
    Map<String, dynamic> job,
  ) {
    return job[
                widget.isProvider
                    ? 'driverPhone'
                    : 'providerPhone']
            as String? ??
        '';
  }

  String statusLabel(
    String status,
  ) {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status
          .replaceAll('_', ' ')
          .trim(),
    };
  }

  RaTone statusTone(
    String status,
  ) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'accepted' ||
      'en_route' ||
      'arrived' =>
        RaTone.success,
      _ => RaTone.info,
    };
  }

  String lastMessagePreview(
    Map<String, dynamic> message,
  ) {
    final imageData =
        message['imageData'];

    if (imageData != null &&
        imageData.toString().isNotEmpty) {
      return 'Photo';
    }

    final text =
        message['text']?.toString().trim() ??
            '';

    if (text.isEmpty) {
      return 'Conversation update';
    }

    return text;
  }

  DateTime? messageTime(
    Map<String, dynamic> message,
  ) {
    final value = message['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String timeLabel(
    DateTime? time,
  ) {
    if (time == null) return '';

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final date = DateTime(
      time.year,
      time.month,
      time.day,
    );

    final difference =
        today.difference(date).inDays;

    if (difference == 0) {
      final hour =
          time.hour % 12 == 0
              ? 12
              : time.hour % 12;

      final minute =
          time.minute
              .toString()
              .padLeft(2, '0');

      final period =
          time.hour >= 12
              ? 'PM'
              : 'AM';

      return '$hour:$minute $period';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    if (difference < 7) {
      const weekdays = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];

      return weekdays[
          time.weekday - 1];
    }

    return '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.year}';
  }

  void openThread(
    String id,
  ) {
    final controller = inbox;

    if (controller == null) {
      return;
    }

    final job =
        controller.jobs[id];

    if (job == null) {
      return;
    }

    push(
      context,
      ChatScreen(
        requestId: id,
        peerName:
            peerNameFor(job),
        peerPhone:
            peerPhoneFor(job),
      ),
    );
  }

  List<String> visibleThreads(
    ChatInboxController controller,
  ) {
    final ids =
        controller.threadIds
            .where((id) {
      final job =
          controller.jobs[id];

      final messages =
          controller
              .conversations[id];

      if (job == null ||
          messages == null ||
          messages.isEmpty) {
        return false;
      }

      if (unreadOnly &&
          controller.unreadFor(id) ==
              0) {
        return false;
      }

      if (searchQuery.isEmpty) {
        return true;
      }

      final peer =
          peerNameFor(job)
              .toLowerCase();

      final issue =
          requestIssueLabel(job)
              .toLowerCase();

      final last =
          lastMessagePreview(
        messages.last,
      ).toLowerCase();

      return peer.contains(
            searchQuery,
          ) ||
          issue.contains(
            searchQuery,
          ) ||
          last.contains(
            searchQuery,
          );
    }).toList();

    ids.sort((a, b) {
      final unreadA =
          controller.unreadFor(a);

      final unreadB =
          controller.unreadFor(b);

      if (unreadA != unreadB) {
        return unreadB.compareTo(
          unreadA,
        );
      }

      final messagesA =
          controller
              .conversations[a];

      final messagesB =
          controller
              .conversations[b];

      if (messagesA == null ||
          messagesA.isEmpty ||
          messagesB == null ||
          messagesB.isEmpty) {
        return 0;
      }

      final timeA =
          messageTime(
        messagesA.last,
      );

      final timeB =
          messageTime(
        messagesB.last,
      );

      if (timeA == null &&
          timeB == null) {
        return 0;
      }

      if (timeA == null) {
        return 1;
      }

      if (timeB == null) {
        return -1;
      }

      return timeB.compareTo(
        timeA,
      );
    });

    return ids;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final controller =
        inbox;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading:
            Navigator.of(context)
                .canPop(),
        titleSpacing:
            RaSpace.lg,
        title: const Text(
          'Messages',
        ),
      ),

      body: controller == null
          ? const Padding(
              padding:
                  EdgeInsets.all(
                RaSpace.lg,
              ),
              child: EmptyState(
                icon:
                    Icons.login_outlined,
                title:
                    'Sign in required',
                message:
                    'Sign in to view your RoadAssist conversations.',
              ),
            )
          : AnimatedBuilder(
              animation:
                  controller,
              builder:
                  (
                context,
                _,
              ) {
                final ids =
                    visibleThreads(
                  controller,
                );

                return Column(
                  children: [
                    Expanded(
                      child:
                          ListView(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          RaSpace.lg,
                          RaSpace.sm,
                          RaSpace.lg,
                          RaSpace.xxxl,
                        ),
                        children: [
                          _InboxHero(
                            unread:
                                controller
                                    .unread,
                            isProvider:
                                widget
                                    .isProvider,
                          ),

                          const SizedBox(
                            height:
                                RaSpace.xl,
                          ),

                          TextField(
                            controller:
                                searchController,
                            decoration:
                                InputDecoration(
                              hintText:
                                  widget.isProvider
                                      ? 'Search drivers or conversations'
                                      : 'Search providers or conversations',
                              prefixIcon:
                                  const Icon(
                                Icons
                                    .search_rounded,
                              ),
                              suffixIcon:
                                  searchQuery
                                          .isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip:
                                              'Clear search',
                                          onPressed:
                                              () {
                                            searchController
                                                .clear();
                                          },
                                          icon:
                                              const Icon(
                                            Icons
                                                .close_rounded,
                                          ),
                                        ),
                            ),
                          ),

                          const SizedBox(
                            height:
                                RaSpace.md,
                          ),

                          _InboxFilterBar(
                            unreadOnly:
                                unreadOnly,
                            onChanged:
                                (
                              value,
                            ) {
                              setState(
                                () {
                                  unreadOnly =
                                      value;
                                },
                              );
                            },
                          ),

                          const SizedBox(
                            height:
                                RaSpace.xl,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    Text(
                                  unreadOnly
                                      ? 'Unread conversations'
                                      : 'Conversations',
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
                              if (controller
                                      .unread >
                                  0)
                                Text(
                                  '${controller.unread} unread',
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color:
                                        colors
                                            .primary,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(
                            height:
                                RaSpace.md,
                          ),

                          if (controller
                              .hasError)
                            const _InboxErrorState(),

                          if (controller
                              .loading)
                            const Padding(
                              padding:
                                  EdgeInsets
                                      .only(
                                bottom:
                                    RaSpace
                                        .md,
                              ),
                              child:
                                  LinearProgressIndicator(
                                minHeight:
                                    3,
                              ),
                            ),

                          if (!controller
                                  .loading &&
                              ids.isEmpty &&
                              !controller
                                  .hasError)
                            _InboxEmptyState(
                              searching:
                                  searchQuery
                                      .isNotEmpty,
                              unreadOnly:
                                  unreadOnly,
                            )
                          else
                            for (
                              var index =
                                  0;
                              index <
                                  ids.length;
                              index++
                            ) ...[
                              _InboxConversationCard(
                                requestId:
                                    ids[index],
                                controller:
                                    controller,
                                isProvider:
                                    widget
                                        .isProvider,
                                onTap:
                                    () =>
                                        openThread(
                                  ids[index],
                                ),
                                statusLabel:
                                    statusLabel,
                                statusTone:
                                    statusTone,
                                lastMessagePreview:
                                    lastMessagePreview,
                                timeLabel:
                                    timeLabel,
                                messageTime:
                                    messageTime,
                              ),

                              if (index !=
                                  ids.length -
                                      1)
                                const SizedBox(
                                  height:
                                      RaSpace
                                          .sm,
                                ),
                            ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _InboxHero
    extends StatelessWidget {
  const _InboxHero({
    required this.unread,
    required this.isProvider,
  });

  final int unread;
  final bool isProvider;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.secondary,
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: .14,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: const Icon(
              Icons
                  .forum_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(
            width: RaSpace.md,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  unread > 0
                      ? '$unread unread ${unread == 1 ? 'message' : 'messages'}'
                      : 'You’re all caught up',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  isProvider
                      ? 'Keep in touch with drivers before, during and after each job.'
                      : 'Keep in touch with your service provider throughout your roadside assistance.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: Colors
                        .white
                        .withValues(
                      alpha: .82,
                    ),
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

class _InboxFilterBar
    extends StatelessWidget {
  const _InboxFilterBar({
    required this.unreadOnly,
    required this.onChanged,
  });

  final bool unreadOnly;
  final ValueChanged<bool>
      onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(4),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: .55,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                _InboxFilterButton(
              label: 'All',
              icon:
                  Icons.forum_outlined,
              selected:
                  !unreadOnly,
              onTap: () =>
                  onChanged(false),
            ),
          ),
          Expanded(
            child:
                _InboxFilterButton(
              label: 'Unread',
              icon: Icons
                  .mark_chat_unread_outlined,
              selected:
                  unreadOnly,
              onTap: () =>
                  onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxFilterButton
    extends StatelessWidget {
  const _InboxFilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      color: selected
          ? colors.surface
          : Colors.transparent,
      borderRadius:
          BorderRadius.circular(
        13,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            vertical: 11,
            horizontal:
                RaSpace.sm,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colors.primary
                    : colors
                        .onSurfaceVariant,
              ),
              const SizedBox(
                width:
                    RaSpace.sm,
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                  color: selected
                      ? colors
                          .primary
                      : colors
                          .onSurfaceVariant,
                  fontWeight:
                      selected
                          ? FontWeight
                              .w800
                          : FontWeight
                              .w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxConversationCard
    extends StatelessWidget {
  const _InboxConversationCard({
    required this.requestId,
    required this.controller,
    required this.isProvider,
    required this.onTap,
    required this.statusLabel,
    required this.statusTone,
    required this.lastMessagePreview,
    required this.timeLabel,
    required this.messageTime,
  });

  final String requestId;
  final ChatInboxController
      controller;
  final bool isProvider;
  final VoidCallback onTap;

  final String Function(
    String status,
  ) statusLabel;

  final RaTone Function(
    String status,
  ) statusTone;

  final String Function(
    Map<String, dynamic>
        message,
  ) lastMessagePreview;

  final String Function(
    DateTime? time,
  ) timeLabel;

  final DateTime? Function(
    Map<String, dynamic>
        message,
  ) messageTime;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final job =
        controller
            .jobs[requestId]!;

    final messages =
        controller
            .conversations[
        requestId]!;

    final last =
        messages.last;

    final unread =
        controller
            .unreadFor(
      requestId,
    );

    final peer =
        job[
                isProvider
                    ? 'driverName'
                    : 'providerName']
            as String? ??
        (isProvider
            ? 'Driver'
            : 'Service Provider');

    final status =
        job['status']
                as String? ??
            '';

    final issue =
        requestIssueLabel(job);

    final preview =
        lastMessagePreview(
      last,
    );

    final sentAt =
        timeLabel(
      messageTime(last),
    );

    return Material(
      color: colors.surface,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        side: BorderSide(
          color: unread > 0
              ? colors.primary
                  .withValues(
                  alpha: .25,
                )
              : colors
                  .outlineVariant
                  .withValues(
                  alpha: .55,
                ),
          width:
              unread > 0
                  ? 1.3
                  : 1,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Stack(
                clipBehavior:
                    Clip.none,
                children: [
                  ProfileInitials(
                    name: peer,
                    radius: 24,
                  ),

                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child:
                          Container(
                        width: 15,
                        height: 15,
                        decoration:
                            BoxDecoration(
                          color: colors
                              .primary,
                          shape: BoxShape
                              .circle,
                          border:
                              Border.all(
                            color: colors
                                .surface,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(
                width: RaSpace.md,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                                  unread >
                                          0
                                      ? FontWeight
                                          .w900
                                      : FontWeight
                                          .w700,
                            ),
                          ),
                        ),

                        if (sentAt
                            .isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              left:
                                  RaSpace
                                      .sm,
                            ),
                            child:
                                Text(
                              sentAt,
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: unread >
                                        0
                                    ? colors
                                        .primary
                                    : colors
                                        .onSurfaceVariant,
                                fontWeight:
                                    unread >
                                            0
                                        ? FontWeight
                                            .w700
                                        : FontWeight
                                            .w500,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        Flexible(
                          child:
                              StatusPill(
                            label:
                                statusLabel(
                              status,
                            ),
                            tone:
                                statusTone(
                              status,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          RaSpace.sm,
                    ),

                    Text(
                      issue,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        if (last[
                                'imageData'] !=
                            null) ...[
                          Icon(
                            Icons
                                .image_outlined,
                            size: 16,
                            color: colors
                                .onSurfaceVariant,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                        ],

                        Expanded(
                          child:
                              Text(
                            preview,
                            maxLines:
                                2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: unread >
                                      0
                                  ? colors
                                      .onSurface
                                  : colors
                                      .onSurfaceVariant,
                              fontWeight:
                                  unread >
                                          0
                                      ? FontWeight
                                          .w600
                                      : FontWeight
                                          .w400,
                            ),
                          ),
                        ),

                        if (unread >
                            0) ...[
                          const SizedBox(
                            width:
                                RaSpace
                                    .sm,
                          ),

                          Container(
                            constraints:
                                const BoxConstraints(
                              minWidth:
                                  24,
                              minHeight:
                                  24,
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  7,
                            ),
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .primary,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                999,
                              ),
                            ),
                            alignment:
                                Alignment
                                    .center,
                            child:
                                Text(
                              unread >
                                      99
                                  ? '99+'
                                  : '$unread',
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: colors
                                    .onPrimary,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                        ],
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

class _InboxErrorState
    extends StatelessWidget {
  const _InboxErrorState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: RaSpace.md,
      ),
      padding:
          const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .errorContainer
            .withValues(
          alpha: .5,
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
                .cloud_off_outlined,
            color: colors.error,
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Expanded(
            child: Text(
              'Some conversations could not be loaded. Check your connection and account access.',
              style: Theme.of(
                context,
              )
                  .textTheme
                  .bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxEmptyState
    extends StatelessWidget {
  const _InboxEmptyState({
    required this.searching,
    required this.unreadOnly,
  });

  final bool searching;
  final bool unreadOnly;

  @override
  Widget build(
    BuildContext context,
  ) {
    final String title;
    final String message;
    final IconData icon;

    if (searching) {
      title =
          'No conversations found';
      message =
          'Try a different provider, driver or message search.';
      icon =
          Icons.search_off_rounded;
    } else if (unreadOnly) {
      title =
          'No unread messages';
      message =
          'You have read all your current conversations.';
      icon = Icons
          .mark_chat_read_outlined;
    } else {
      title =
          'No conversations yet';
      message =
          'Messages from active and completed roadside jobs will appear here.';
      icon =
          Icons.forum_outlined;
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        top: RaSpace.md,
      ),
      child: EmptyState(
        icon: icon,
        title: title,
        message: message,
      ),
    );
  }
}