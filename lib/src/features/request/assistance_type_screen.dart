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
      'For a vehicle that cannot be driven safely and needs recovery.',
      Icons.fire_truck_outlined,
    ),
    (
      'Flat Tyre',
      'Puncture, tyre damage or help fitting a spare tyre.',
      Icons.tire_repair_outlined,
    ),
    (
      'Battery Jumpstart',
      'Dead battery, starting problem or basic battery assistance.',
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
    final updated = await draftStore.lastUpdated();

    if (!mounted) return;

    setState(() {
      savedDraft = draft;
      savedAt = updated;
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

  String savedTime(DateTime? value) {
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
      return;
    }

    if (!draft.location.startsWith('Select current GPS')) {
      push(context, ProvidersScreen(draft: draft));
      return;
    }

    push(
      context,
      BreakdownDetailsScreen(issues: draft.issues, initialDraft: draft),
    );
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

  void unknownProblem() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Request Assistance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const _RaAssistProgress(),

                  const SizedBox(height: 16),

                  const _RaAssistHero(),

                  if (loadingDraft) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .45),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text('Checking saved request...')),
                        ],
                      ),
                    ),
                  ] else if (savedDraft != null) ...[
                    const SizedBox(height: 14),
                    _RaAssistSavedDraft(
                      draft: savedDraft!,
                      savedLabel: savedTime(savedAt),
                      onResume: resumeSavedRequest,
                      onDelete: discardSavedDraft,
                    ),
                  ],

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: raGold.withValues(alpha: .075),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          color: raGold,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'If you are in immediate danger, move to a safe place when possible and contact emergency services first.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose assistance',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Select every issue that applies.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
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

                  const SizedBox(height: 11),

                  LayoutBuilder(
                    builder: (context, box) {
                      final single =
                          box.maxWidth < 310 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20;
                      final width = single
                          ? box.maxWidth
                          : (box.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var index = 0; index < items.length; index++)
                            SizedBox(
                              width: width,
                              child: RaDriverServiceTile(
                                title: items[index].$1,
                                icon: items[index].$3,
                                selected: selected.contains(index),
                                onTap: () => toggle(index),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 13),

                  _RaAssistUnknownCard(onTap: unknownProblem),

                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.request_quote_outlined,
                          color: colors.primary,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Choosing a service does not confirm a price. Providers review the request and submit offers before assignment.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected.isNotEmpty) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${selected.length} ${selected.length == 1 ? 'issue' : 'issues'} selected',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),

                          Text(
                            'Next: Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty ? null : continueRequest,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          selected.isEmpty
                              ? 'Select an Issue'
                              : 'Continue to Details',
                        ),
                      ),
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

class _RaAssistProgress extends StatelessWidget {
  const _RaAssistProgress();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'STEP 1 OF 4',
                style: GoogleFonts.plusJakartaSans(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),

            Text(
              'Issue',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: .25,
            minHeight: 5,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RaAssistHero extends StatelessWidget {
  const _RaAssistHero();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'What do you need help with?',
        style: _providerText(context, size: 24, weight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Select the services you need. You can add vehicle details and photos next.',
        style: _providerText(context, size: 14, muted: true),
      ),
    ],
  );
}

class _RaAssistUnknownCard extends StatelessWidget {
  const _RaAssistUnknownCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.secondary.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: colors.secondary.withValues(alpha: .15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I don’t know the problem',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Describe the symptoms and let a provider inspect the vehicle first.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: colors.secondary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaAssistSavedDraft extends StatelessWidget {
  const _RaAssistSavedDraft({
    required this.draft,
    required this.savedLabel,
    required this.onResume,
    required this.onDelete,
  });

  final RequestDraft draft;
  final String savedLabel;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.secondary.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.history_rounded, color: colors.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue saved request',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      savedLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Discard draft',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              draft.issue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume Request'),
          ),
        ],
      ),
    );
  }
}
