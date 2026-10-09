part of '../../screens.dart';

class CustomerContactScreen extends StatelessWidget {
  const CustomerContactScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  final String requestId;
  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final driver = requestData['driverName'] as String? ?? 'Driver';

    final phone = requestData['driverPhone'] as String? ?? '';

    final rawStatus = requestData['status'] as String? ?? 'unknown';

    final status = rawStatus.replaceAll('_', ' ');

    final vehicle = [
      requestData['modelYear'],
      requestData['registration'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');

    final issue = requestIssueLabel(requestData);

    final location =
        requestData['locationLabel'] as String? ?? 'Location not recorded';

    final active = const [
      'accepted',
      'en_route',
      'arrived',
    ].contains(rawStatus);

    return RaProviderScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            BrandMark(size: 26),
            SizedBox(width: 8),
            Expanded(child: Text('Customer Contact')),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _WelcomeThemeToggle(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: RaSpace.md),
            child: StatusPill(
              label: active ? 'Active Job' : status.toUpperCase(),
              tone: active ? RaTone.success : RaTone.info,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.lg,
                  RaSpace.md,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  RaProviderSummaryCard(
                    title: driver,
                    message: phone.isEmpty
                        ? 'Phone number not provided'
                        : phone,
                    icon: Icons.person_outline,
                    status: StatusPill(
                      label: active ? 'Active job' : status,
                      tone: active ? RaTone.success : RaTone.neutral,
                    ),
                  ),

                  const SizedBox(height: RaSpace.xxl),

                  Text(
                    'Job information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: RaSpace.lg),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .6),
                      ),
                    ),
                    child: Column(
                      children: [
                        _CustomerContactRow(
                          icon: Icons.tag_outlined,
                          label: 'Request ID',
                          value: requestId,
                        ),
                        const Divider(height: 1),
                        _CustomerContactRow(
                          icon: Icons.sync_outlined,
                          label: 'Status',
                          value: status,
                        ),
                        const Divider(height: 1),
                        _CustomerContactRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Vehicle',
                          value: vehicle.isEmpty ? 'Not provided' : vehicle,
                        ),
                        const Divider(height: 1),
                        _CustomerContactRow(
                          icon: Icons.car_repair_outlined,
                          label: 'Issue',
                          value: issue,
                        ),
                        const Divider(height: 1),
                        _CustomerContactRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: location,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  Container(
                    padding: const EdgeInsets.all(RaSpace.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .35,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 19),
                        SizedBox(width: RaSpace.sm),
                        Expanded(
                          child: Text(
                            'Customer contact information is provided only for this assigned assistance request. Use it only for service-related communication.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.lg,
                RaSpace.sm,
                RaSpace.lg,
                RaSpace.md,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: phone.isEmpty
                                ? null
                                : () => showCallPrompt(
                                    context,
                                    name: driver,
                                    number: phone,
                                  ),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call'),
                          ),
                        ),

                        const SizedBox(width: RaSpace.sm),

                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => push(
                              context,
                              ChatScreen(
                                requestId: requestId,
                                peerName: driver,
                                peerPhone: phone,
                              ),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Open Messages'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: RaSpace.sm),

                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: const Text('Back to Job'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerContactRow extends StatelessWidget {
  const _CustomerContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RaSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: colors.primary),
          ),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
