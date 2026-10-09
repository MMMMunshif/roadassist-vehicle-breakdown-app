part of '../../screens.dart';

class _ChatInboxScreen extends StatefulWidget {
  const _ChatInboxScreen({required this.isProvider});

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
      inbox = ChatInboxController(isProvider: widget.isProvider);
    }

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchQuery = searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    inbox?.dispose();
    super.dispose();
  }

  String peerNameFor(Map<String, dynamic> job) {
    return job[widget.isProvider ? 'driverName' : 'providerName'] as String? ??
        (widget.isProvider ? 'Driver' : 'Service Provider');
  }

  String peerPhoneFor(Map<String, dynamic> job) {
    return job[widget.isProvider ? 'driverPhone' : 'providerPhone']
            as String? ??
        '';
  }

  String statusLabel(String status) {
    return switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' ').trim(),
    };
  }

  RaTone statusTone(String status) {
    return switch (status) {
      'completed' => RaTone.success,
      'cancelled' => RaTone.danger,
      'accepted' || 'en_route' || 'arrived' => RaTone.success,
      _ => RaTone.info,
    };
  }

  String lastMessagePreview(Map<String, dynamic> message) {
    final imageData = message['imageData'];

    if (imageData != null && imageData.toString().isNotEmpty) {
      return '📷 Photo';
    }

    final text = message['text']?.toString().trim() ?? '';

    return text.isEmpty ? 'Conversation update' : text;
  }

  DateTime? messageTime(Map<String, dynamic> message) {
    final value = message['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String timeLabel(DateTime? time) {
    if (time == null) return '';

    final local = time.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final date = DateTime(local.year, local.month, local.day);

    final difference = today.difference(date).inDays;

    if (difference == 0) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;

      final minute = local.minute.toString().padLeft(2, '0');

      final period = local.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    if (difference < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return weekdays[local.weekday - 1];
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }

  void openThread(String id) {
    final controller = inbox;

    if (controller == null) return;

    final job = controller.jobs[id];

    if (job == null) return;

    push(
      context,
      ChatScreen(
        requestId: id,
        peerName: peerNameFor(job),
        peerPhone: peerPhoneFor(job),
      ),
    );
  }

  List<String> visibleThreads(ChatInboxController controller) {
    final ids = controller.threadIds.where((id) {
      final job = controller.jobs[id];
      final messages = controller.conversations[id];

      if (job == null || messages == null || messages.isEmpty) {
        return false;
      }

      if (unreadOnly && controller.unreadFor(id) == 0) {
        return false;
      }

      if (searchQuery.isEmpty) {
        return true;
      }

      final peer = peerNameFor(job).toLowerCase();

      final issue = requestIssueLabel(job).toLowerCase();

      final last = lastMessagePreview(messages.last).toLowerCase();

      return peer.contains(searchQuery) ||
          issue.contains(searchQuery) ||
          last.contains(searchQuery);
    }).toList();

    ids.sort((a, b) {
      final unreadA = controller.unreadFor(a);

      final unreadB = controller.unreadFor(b);

      if (unreadA != unreadB) {
        return unreadB.compareTo(unreadA);
      }

      final messagesA = controller.conversations[a];

      final messagesB = controller.conversations[b];

      if (messagesA == null ||
          messagesA.isEmpty ||
          messagesB == null ||
          messagesB.isEmpty) {
        return 0;
      }

      final timeA = messageTime(messagesA.last);

      final timeB = messageTime(messagesB.last);

      if (timeA == null && timeB == null) {
        return 0;
      }

      if (timeA == null) return 1;
      if (timeB == null) return -1;

      return timeB.compareTo(timeA);
    });

    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final controller = inbox;

    return RaScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: Text(
          'Messages',
          style: GoogleFonts.plusJakartaSans(
            fontSize: providerFontSize(context, 20),
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
      ),
      body: controller == null
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message: 'Sign in to view your RoadAssist conversations.',
              ),
            )
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final ids = visibleThreads(controller);

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    _RaInboxHero(
                      unread: controller.unread,
                      isProvider: widget.isProvider,
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: widget.isProvider
                            ? 'Search drivers or conversations'
                            : 'Search providers or conversations',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),

                    const SizedBox(height: 11),

                    _RaInboxFilterBar(
                      unreadOnly: unreadOnly,
                      onChanged: (value) {
                        setState(() {
                          unreadOnly = value;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unreadOnly
                                ? 'Unread conversations'
                                : 'Conversations',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: providerFontSize(context, 17),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.35,
                              color: colors.onSurface,
                            ),
                          ),
                        ),

                        if (controller.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${controller.unread} unread',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: providerFontSize(context, 9),
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 11),

                    if (controller.hasError) const _RaInboxError(),

                    if (controller.loading) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 12),
                    ],

                    if (!controller.loading &&
                        ids.isEmpty &&
                        !controller.hasError)
                      _RaInboxEmpty(
                        searching: searchQuery.isNotEmpty,
                        unreadOnly: unreadOnly,
                      )
                    else
                      for (var i = 0; i < ids.length; i++) ...[
                        _RaInboxConversationCard(
                          requestId: ids[i],
                          controller: controller,
                          isProvider: widget.isProvider,
                          onTap: () {
                            openThread(ids[i]);
                          },
                          statusLabel: statusLabel,
                          statusTone: statusTone,
                          lastMessagePreview: lastMessagePreview,
                          timeLabel: timeLabel,
                          messageTime: messageTime,
                        ),
                        if (i != ids.length - 1) const SizedBox(height: 9),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

// =============================================================================
// HERO
// =============================================================================

class _RaInboxHero extends StatelessWidget {
  const _RaInboxHero({required this.unread, required this.isProvider});

  final int unread;
  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    if (RaProviderTheme.isActive(context)) {
      return RaProviderSummaryCard(
        title: unread > 0 ? '$unread unread messages' : 'You are all caught up',
        message: 'Stay connected with drivers throughout each roadside job.',
        icon: Icons.forum_outlined,
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0C477B), Color(0xFF08655D)]
              : const [Color(0xFF075BA8), Color(0xFF078C7E)],
        ),
        borderRadius: BorderRadius.circular(24),
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
              Icons.forum_outlined,
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
                  unread > 0
                      ? '$unread unread ${unread == 1 ? 'message' : 'messages'}'
                      : 'You’re all caught up',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: providerFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  isProvider
                      ? 'Stay connected with drivers throughout each roadside job.'
                      : 'Stay connected with your provider throughout roadside assistance.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: providerFontSize(context, 10),
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

// =============================================================================
// FILTERS
// =============================================================================

class _RaInboxFilterBar extends StatelessWidget {
  const _RaInboxFilterBar({required this.unreadOnly, required this.onChanged});

  final bool unreadOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RaInboxFilterButton(
              label: 'All',
              icon: Icons.forum_outlined,
              selected: !unreadOnly,
              onTap: () {
                onChanged(false);
              },
            ),
          ),

          Expanded(
            child: _RaInboxFilterButton(
              label: 'Unread',
              icon: Icons.mark_chat_unread_outlined,
              selected: unreadOnly,
              onTap: () {
                onChanged(true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RaInboxFilterButton extends StatelessWidget {
  const _RaInboxFilterButton({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),

              const SizedBox(width: 6),

              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: providerFontSize(context, 10.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CONVERSATION CARD
// =============================================================================

class _RaInboxConversationCard extends StatelessWidget {
  const _RaInboxConversationCard({
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
  final ChatInboxController controller;
  final bool isProvider;

  final VoidCallback onTap;

  final String Function(String) statusLabel;

  final RaTone Function(String) statusTone;

  final String Function(Map<String, dynamic>) lastMessagePreview;

  final String Function(DateTime?) timeLabel;

  final DateTime? Function(Map<String, dynamic>) messageTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    final job = controller.jobs[requestId]!;

    final messages = controller.conversations[requestId]!;

    final last = messages.last;

    final unread = controller.unreadFor(requestId);

    final peer =
        job[isProvider ? 'driverName' : 'providerName'] as String? ??
        (isProvider ? 'Driver' : 'Service Provider');

    final status = job['status'] as String? ?? '';

    final issue = requestIssueLabel(job);

    final preview = lastMessagePreview(last);

    final sentAt = timeLabel(messageTime(last));

    return Material(
      color: dark ? const Color(0xFF0D1D2B) : Colors.white,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: unread > 0
                  ? colors.primary.withValues(alpha: .25)
                  : colors.outlineVariant.withValues(alpha: .46),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileInitials(name: peer, radius: 23),

                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: raDanger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: dark
                                ? const Color(0xFF0D1D2B)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: providerFontSize(context, 7.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.onSurface,
                              fontSize: providerFontSize(context, 12.5),
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),

                        if (sentAt.isNotEmpty)
                          Text(
                            sentAt,
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.onSurfaceVariant,
                              fontSize: providerFontSize(context, 8.5),
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        StatusPill(
                          label: statusLabel(status),
                          tone: statusTone(status),
                        ),

                        const SizedBox(width: 7),

                        Expanded(
                          child: Text(
                            issue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.onSurfaceVariant,
                              fontSize: providerFontSize(context, 9),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: providerFontSize(context, 10.5),
                        height: 1.35,
                        color: unread > 0
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ERROR STATE
// =============================================================================

class _RaInboxError extends StatelessWidget {
  const _RaInboxError();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: .12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.error, size: 19),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              'Some conversations could not be loaded. Check your connection.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: providerFontSize(context, 10),
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

// =============================================================================
// EMPTY STATE
// =============================================================================

class _RaInboxEmpty extends StatelessWidget {
  const _RaInboxEmpty({required this.searching, required this.unreadOnly});

  final bool searching;
  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No conversations found',
        message: 'Try another provider, driver or message search.',
      );
    }

    if (unreadOnly) {
      return const EmptyState(
        icon: Icons.mark_chat_read_outlined,
        title: 'No unread messages',
        message: 'You have read all of your current conversations.',
      );
    }

    return const EmptyState(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      message: 'Messages connected to roadside requests will appear here.',
    );
  }
}
