part of '../../screens.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  static const activeStatuses = <String>{
    'searching',
    'accepted',
    'en_route',
    'arrived',
  };

  bool matchesFilter(String status) {
    switch (filter) {
      case 1:
        return activeStatuses.contains(status);
      case 2:
        return status == 'completed';
      case 3:
        return status == 'cancelled';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: RaSpace.xl,
        title: const Text('Requests'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => push(
              context,
              const DriverNotificationsScreen(),
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const SizedBox(width: RaSpace.sm),
        ],
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(RaSpace.xl),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a driver to view your assistance requests.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService().watchDriverRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(RaSpace.xl),
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load requests',
                      message:
                          'Check your connection and try again.',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const _DriverHistoryLoadingView();
                }

                final allRequests = [...snapshot.data!.docs];

                allRequests.sort((a, b) {
                  final aTime =
                      a.data()['createdAt'] as Timestamp?;
                  final bTime =
                      b.data()['createdAt'] as Timestamp?;

                  if (aTime == null && bTime == null) {
                    return 0;
                  }

                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });

                final activeCount = allRequests.where((request) {
                  final status =
                      request.data()['status'] as String? ?? '';
                  return activeStatuses.contains(status);
                }).length;

                final completedCount =
                    allRequests.where((request) {
                  return request.data()['status'] == 'completed';
                }).length;

                final cancelledCount =
                    allRequests.where((request) {
                  return request.data()['status'] == 'cancelled';
                }).length;

                final filteredRequests =
                    allRequests.where((request) {
                  final status =
                      request.data()['status'] as String? ?? '';

                  return matchesFilter(status);
                }).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          RaSpace.lg,
                          RaSpace.sm,
                          RaSpace.lg,
                          RaSpace.xxxl,
                        ),
                        children: [
                          _DriverRequestsOverview(
                            total: allRequests.length,
                            active: activeCount,
                            completed: completedCount,
                          ),

                          const SizedBox(
                            height: RaSpace.xl,
                          ),

                          Text(
                            'Your assistance',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Track current roadside help and review previous requests.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(
                            height: RaSpace.lg,
                          ),

                          _DriverRequestFilterBar(
                            selected: filter,
                            onSelected: (value) {
                              setState(() => filter = value);
                            },
                          ),

                          const SizedBox(
                            height: RaSpace.lg,
                          ),

                          if (filteredRequests.isEmpty)
                            _DriverHistoryEmptyState(
                              filter: filter,
                            )
                          else
                            ...[
                              for (
                                var index = 0;
                                index < filteredRequests.length;
                                index++
                              ) ...[
                                _DriverHistoryCard(
                                  requestId:
                                      filteredRequests[index].id,
                                  data: filteredRequests[index].data(),
                                ),
                                if (index !=
                                    filteredRequests.length - 1)
                                  const SizedBox(
                                    height: RaSpace.md,
                                  ),
                              ],
                            ],

                          if (cancelledCount > 0 &&
                              filter == 0) ...[
                            const SizedBox(
                              height: RaSpace.xl,
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(
                                  width: RaSpace.sm,
                                ),
                                Expanded(
                                  child: Text(
                                    'Cancelled requests remain in your history for reference.',
                                    style:
                                        theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
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

class _DriverRequestsOverview extends StatelessWidget {
  const _DriverRequestsOverview({
    required this.total,
    required this.active,
    required this.completed,
  });

  final int total;
  final int active;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(RaSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REQUEST OVERVIEW',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: RaSpace.sm),

          Text(
            active > 0
                ? '$active active ${active == 1 ? 'request' : 'requests'}'
                : 'No active requests',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),

          const SizedBox(height: 4),

          Text(
            active > 0
                ? 'Your current roadside assistance is still in progress.'
                : 'Start a new request whenever you need roadside help.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                ),
          ),

          const SizedBox(height: RaSpace.lg),

          Row(
            children: [
              Expanded(
                child: _DriverRequestMetric(
                  value: '$active',
                  label: 'Active',
                  icon: Icons.route_rounded,
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: _DriverRequestMetric(
                  value: '$completed',
                  label: 'Completed',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: _DriverRequestMetric(
                  value: '$total',
                  label: 'Total',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverRequestMetric extends StatelessWidget {
  const _DriverRequestMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RaSpace.sm,
        vertical: RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: .12),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: .78),
                ),
          ),
        ],
      ),
    );
  }
}

class _DriverRequestFilterBar extends StatelessWidget {
  const _DriverRequestFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const filters = [
    (
      'All',
      Icons.apps_rounded,
    ),
    (
      'Active',
      Icons.route_outlined,
    ),
    (
      'Completed',
      Icons.check_circle_outline_rounded,
    ),
    (
      'Cancelled',
      Icons.cancel_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0;
              index < filters.length;
              index++) ...[
            if (index > 0)
              const SizedBox(
                width: RaSpace.sm,
              ),
            ChoiceChip(
              selected: selected == index,
              onSelected: (_) => onSelected(index),
              avatar: Icon(
                filters[index].$2,
                size: 17,
                color: selected == index
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
              label: Text(
                filters[index].$1,
              ),
              labelStyle:
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected == index
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant,
                        fontWeight: selected == index
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
              selectedColor: colors.secondaryContainer,
              backgroundColor: colors.surface,
              side: BorderSide(
                color: selected == index
                    ? colors.secondary.withValues(alpha: .25)
                    : colors.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: RaSpace.sm,
                vertical: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverHistoryEmptyState extends StatelessWidget {
  const _DriverHistoryEmptyState({
    required this.filter,
  });

  final int filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (filter) {
      1 => (
          Icons.route_outlined,
          'No active requests',
          'You do not have any roadside assistance in progress.',
        ),
      2 => (
          Icons.check_circle_outline_rounded,
          'No completed requests',
          'Completed roadside assistance will appear here.',
        ),
      3 => (
          Icons.cancel_outlined,
          'No cancelled requests',
          'Cancelled requests will appear here.',
        ),
      _ => (
          Icons.receipt_long_outlined,
          'No requests yet',
          'Your roadside assistance requests will appear here.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(
        top: RaSpace.lg,
      ),
      child: EmptyState(
        icon: icon,
        title: title,
        message: message,
      ),
    );
  }
}

class _DriverHistoryLoadingView extends StatelessWidget {
  const _DriverHistoryLoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(RaSpace.lg),
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        Container(
          width: 150,
          height: 24,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 165,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RaRadius.lg),
              border: Border.all(
                color: colors.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: RaSpace.md),
        ],
      ],
    );
  }
}