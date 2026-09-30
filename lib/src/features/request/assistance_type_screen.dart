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

  String formatEstimate(String issue) {
    final value = estimatedCostForIssue(issue).toString();
    final formatted = value.length > 3
        ? '${value.substring(0, value.length - 3)},${value.substring(value.length - 3)}'
        : value;
    return 'Estimated from Rs. $formatted';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assistance Type')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                const StepEyebrow(step: 1, of: 4),
                const SizedBox(height: RaSpace.xl),
                const Text("What's the issue?", style: RaText.headline),
                const SizedBox(height: RaSpace.xs),
                const Text(
                  'Select every problem that applies. We will match a provider who supports all selected services.',
                  style: RaText.bodyMuted,
                ),
                if (loadingDraft) ...[
                  const SizedBox(height: RaSpace.lg),
                  const LinearProgressIndicator(),
                ] else if (savedDraft != null) ...[
                  const SizedBox(height: RaSpace.lg),
                  Card(
                    color: raPale,
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.drafts_outlined, color: raBlue),
                              SizedBox(width: RaSpace.sm),
                              Text(
                                'Continue saved request',
                                style: RaText.title,
                              ),
                            ],
                          ),
                          const SizedBox(height: RaSpace.xs),
                          Text(
                            '${savedDraft!.issue}\n${formatSavedTime(savedAt)}',
                            style: RaText.bodyMuted,
                          ),
                          const SizedBox(height: RaSpace.sm),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: resumeSavedRequest,
                                  child: const Text('Resume Draft'),
                                ),
                              ),
                              const SizedBox(width: RaSpace.sm),
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
                  ),
                ],
                const SizedBox(height: RaSpace.lg),
                const SafetyBox(),
                const SizedBox(height: RaSpace.md),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RaSpace.sm),
                    child: Card(
                      color: selected.contains(i) ? raPale : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RaRadius.md),
                        side: BorderSide(
                          color: selected.contains(i) ? raBlue : raLine,
                          width: selected.contains(i) ? 1.6 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RaSpace.md,
                          vertical: 4,
                        ),
                        value: selected.contains(i),
                        onChanged: (checked) => setState(() {
                          checked == true
                              ? selected.add(i)
                              : selected.remove(i);
                        }),
                        secondary: IconBadge(items[i].$3),
                        title: Text(items[i].$1, style: RaText.title),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: RaSpace.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].$2, style: RaText.caption),
                              const SizedBox(height: RaSpace.xs),
                              Text(
                                formatEstimate(items[i].$1),
                                style: const TextStyle(
                                  color: raBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          BottomAction(
            label: selected.isEmpty
                ? 'Select at least one issue'
                : 'Continue with ${selected.length} issue${selected.length == 1 ? '' : 's'}',
            enabled: selected.isNotEmpty,
            onTap: () {
              final issues = selected.map((index) => items[index].$1).toList();
              push(context, BreakdownDetailsScreen(issues: issues));
            },
          ),
        ],
      ),
    ),
  );
}
