part of '../../screens.dart';

// Presentation uses the shared RoadAssist theme; draft behavior is unchanged.

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
      'Engine sounds, brakes, or general mechanical failure.',
      Icons.car_repair,
    ),
    (
      'Vehicle Towing',
      'Vehicle cannot be driven and needs recovery transport.',
      Icons.fire_truck_outlined,
    ),
    (
      'Flat Tyre',
      'Puncture repair or spare tyre replacement service.',
      Icons.tire_repair,
    ),
    (
      'Battery Jumpstart',
      'Dead battery or electrical starting issues.',
      Icons.battery_charging_full,
    ),
  ];

  @override
  void initState() {
    super.initState();
    loadSavedDraft();
  }

  // ---------------------------------------------------------------------------
  // LOGIC (unchanged)
  // ---------------------------------------------------------------------------

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
    if (value == null) return 'Saved request available';
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

  void toggle(int index) => setState(() {
    selected.contains(index) ? selected.remove(index) : selected.add(index);
  });

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildDraftCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue saved request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${savedDraft!.issue}\n${formatSavedTime(savedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: resumeSavedRequest,
                  child: const Text('Resume Draft'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Discard draft',
                onPressed: discardSavedDraft,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildIssueCard(int i) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSelected = selected.contains(i);
    final item = items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: isSelected,
        button: true,
        child: Material(
          color: isSelected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? colors.primary : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => toggle(i),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$3, color: colors.primary, size: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(item.$2, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 10),
                        Text(
                          'Provider quote required',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? colors.primary : colors.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final enabled = selected.isNotEmpty;
    final label = selected.isEmpty
        ? 'Select at least one issue'
        : 'Continue with ${selected.length} issue${selected.length == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled
                  ? () {
                      final issues = selected
                          .map((index) => items[index].$1)
                          .toList();
                      push(context, BreakdownDetailsScreen(issues: issues));
                    }
                  : null,
              child: Text(label),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: const Text("I don't know the problem"),
            onPressed: () => push(
              context,
              BreakdownDetailsScreen(
                issues: const ['General Mechanic'],
                initialDraft: RequestDraft(
                  issues: ['General Mechanic'],
                  vehicleType: 'Sedan / Hatchback',
                  modelYear: '',
                  registration: '',
                  description: 'I am not sure what the problem is. ',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Assistance Type')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const StepEyebrow(step: 1, of: 4),
                  const SizedBox(height: 24),
                  Text(
                    "What's the issue?",
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select every problem that applies. We will match a provider who supports all selected services.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (loadingDraft) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(),
                  ] else if (savedDraft != null) ...[
                    const SizedBox(height: 20),
                    _buildDraftCard(),
                  ],
                  const SizedBox(height: 20),
                  const SafetyBox(),
                  const SizedBox(height: 20),
                  for (var i = 0; i < items.length; i++) _buildIssueCard(i),
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
