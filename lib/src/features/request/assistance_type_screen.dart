part of '../../screens.dart';

class AssistanceTypeScreen extends StatefulWidget {
  const AssistanceTypeScreen({super.key});

  @override
  State<AssistanceTypeScreen> createState() => _AssistanceTypeScreenState();
}

class _AssistanceTypeScreenState extends State<AssistanceTypeScreen> {
  final selected = <int>{};

  final draftStore = RequestDraftStore();

  RequestDraft? savedDraft;
  DateTime? savedAt;

  bool loadingDraft = true;

  final items = const [
    (
      'General Mechanic',
      'Engine sounds, brakes, warning lights or general mechanical problems.',
      Icons.car_repair_outlined,
    ),
    (
      'Vehicle Towing',
      'Choose this when your vehicle cannot be driven safely and needs recovery.',
      Icons.fire_truck_outlined,
    ),
    (
      'Flat Tyre',
      'Get help with a puncture, tyre damage or fitting your spare tyre.',
      Icons.tire_repair_outlined,
    ),
    (
      'Battery Jumpstart',
      'For a dead battery, starting issue or basic battery assistance.',
      Icons.battery_charging_full_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    loadSavedDraft();
  }

  Future<void> loadSavedDraft() async {
    final draft = await draftStore.load();
    final updatedAt = await draftStore.lastUpdated();

    if (!mounted) return;

    setState(() {
      savedDraft = draft;
      savedAt = updatedAt;
      loadingDraft = false;
    });
  }

  Future<void> discardSavedDraft() async {
    await draftStore.clear();

    if (!mounted) return;

    setState(() {
      savedDraft = null;
      savedAt = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved request draft removed.')),
    );
  }

  String formatSavedTime(DateTime? value) {
    if (value == null) {
      return 'Saved request available';
    }

    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return 'Saved ${value.day}/${value.month}/${value.year} at $hour:$minute';
  }

  void resumeSavedRequest() {
    final draft = savedDraft;

    if (draft == null) return;

    if (draft.preferredProviderId.isNotEmpty) {
      push(context, ReviewScreen(draft: draft));
    } else if (!draft.location.startsWith('Select current GPS')) {
      push(context, ProvidersScreen(draft: draft));
    } else {
      push(
        context,
        BreakdownDetailsScreen(issues: draft.issues, initialDraft: draft),
      );
    }
  }

  void toggle(int index) {
    setState(() {
      if (selected.contains(index)) {
        selected.remove(index);
      } else {
        selected.add(index);
      }
    });
  }

  void continueRequest() {
    if (selected.isEmpty) return;

    final issues = selected.map((index) => items[index].$1).toList();

    push(context, BreakdownDetailsScreen(issues: issues));
  }

  void startUnknownProblem() {
    push(
      context,
      BreakdownDetailsScreen(
        issues: const ['General Mechanic'],
        initialDraft: RequestDraft(
          issues: const ['General Mechanic'],
          vehicleType: 'Sedan / Hatchback',
          modelYear: '',
          registration: '',
          description: 'I am not sure what the problem is. ',
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.looks_one_outlined,
                    size: 16,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'STEP 1 OF 4',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Text(
              'Issue',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: RaSpace.sm),

        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .25,
            minHeight: 6,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildIntroHero(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    final start = dark ? const Color(0xFF0B4C84) : colors.primary;

    final end = dark ? const Color(0xFF08675E) : const Color(0xFF007D70);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RaSpace.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -25,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
          ),

          Positioned(
            right: 6,
            bottom: -18,
            child: Icon(
              Icons.car_repair_outlined,
              size: 115,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_road_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(height: RaSpace.lg),

              Text(
                'What happened?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),

              const SizedBox(height: 6),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'Choose every issue that applies. RoadAssist will use these details to find suitable providers.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard() {
    final draft = savedDraft!;

    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.secondary.withValues(alpha: .20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),

                const SizedBox(width: RaSpace.md),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue saved request',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'You have an unfinished roadside assistance request.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Discard draft',
                  onPressed: discardSavedDraft,
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
              ],
            ),

            const SizedBox(height: RaSpace.md),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.issue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          formatSavedTime(savedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: RaSpace.md),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: resumeSavedRequest,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(int index) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final item = items[index];

    final isSelected = selected.contains(index);

    return Semantics(
      selected: isSelected,
      button: true,
      label: '${item.$1}. ${item.$2}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primaryContainer.withValues(alpha: .55)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: .65)
                : colors.outlineVariant.withValues(alpha: .65),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => toggle(index),
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      item.$3,
                      size: 27,
                      color: isSelected
                          ? colors.onPrimary
                          : colors.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(width: RaSpace.md),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.$1,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),

                            const SizedBox(width: RaSpace.sm),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? colors.primary
                                    : colors.outline,
                                size: 24,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        Text(
                          item.$2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: RaSpace.sm),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: .10)
                                : colors.surfaceContainerHighest.withValues(
                                    alpha: .6,
                                  ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.request_quote_outlined,
                                size: 14,
                                color: isSelected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Provider quote required',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnknownProblemCard(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Material(
      color: colors.tertiaryContainer.withValues(alpha: .36),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: startUnknownProblem,
        child: Container(
          padding: const EdgeInsets.all(RaSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.tertiary.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: colors.onTertiaryContainer,
                ),
              ),

              const SizedBox(width: RaSpace.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not sure what is wrong?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Describe the symptoms instead. A provider can inspect the vehicle before repair work is approved.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: RaSpace.sm),

              Icon(Icons.arrow_forward_rounded, color: colors.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final enabled = selected.isNotEmpty;

    final count = selected.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        RaSpace.lg,
        RaSpace.sm,
        RaSpace.lg,
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enabled) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: colors.primary,
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      '$count ${count == 1 ? 'issue' : 'issues'} selected',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  Text(
                    'Next: Details',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: RaSpace.sm),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? continueRequest : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  enabled ? 'Continue' : 'Select an issue to continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(title: const Text('Request Assistance')),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.lg,
                  RaSpace.sm,
                  RaSpace.lg,
                  RaSpace.xxl,
                ),
                children: [
                  _buildProgressHeader(context),

                  const SizedBox(height: RaSpace.lg),

                  _buildIntroHero(context),

                  if (loadingDraft) ...[
                    const SizedBox(height: RaSpace.lg),

                    Container(
                      padding: const EdgeInsets.all(RaSpace.md),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .6),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: RaSpace.md),
                          Text('Checking for a saved request…'),
                        ],
                      ),
                    ),
                  ] else if (savedDraft != null) ...[
                    const SizedBox(height: RaSpace.lg),
                    _buildDraftCard(),
                  ],

                  const SizedBox(height: RaSpace.xl),

                  const SafetyBox(),

                  const SizedBox(height: RaSpace.xxl),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose assistance',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'You can select more than one issue.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (selected.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selected.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),

                  const SizedBox(height: RaSpace.md),

                  for (var index = 0; index < items.length; index++) ...[
                    _buildIssueCard(index),

                    if (index != items.length - 1)
                      const SizedBox(height: RaSpace.sm),
                  ],

                  const SizedBox(height: RaSpace.lg),

                  _buildUnknownProblemCard(context),

                  const SizedBox(height: RaSpace.lg),

                  Container(
                    padding: const EdgeInsets.all(RaSpace.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .40,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 19,
                          color: colors.primary,
                        ),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Text(
                            'Selecting a service does not confirm a price. Providers review your request and submit an offer before assignment.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
}
