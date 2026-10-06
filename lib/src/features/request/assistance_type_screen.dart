part of '../../screens.dart';

// Uses the shared glass helpers from driver_home_screen.dart:
// _Glass, _onGlass, _glassNavyTop, _glassNavyMid, _glassBlueBottom
// (all parts of screens.dart share one library, so no import is needed).

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

  Widget _buildDraftCard() {
    return _Glass(
      radius: 22,
      tint: const Color(0xFF5B9BFF),
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.drafts_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: RaSpace.md),
              const Expanded(
                child: Text(
                  'Continue saved request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.sm),
          Text(
            '${savedDraft!.issue}\n${formatSavedTime(savedAt)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: RaSpace.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: resumeSavedRequest,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Resume Draft',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              IconButton(
                tooltip: 'Discard draft',
                onPressed: discardSavedDraft,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(int i) {
    final isSelected = selected.contains(i);
    final item = items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: RaSpace.md),
      child: Stack(
        children: [
          _Glass(
            radius: 22,
            tint: isSelected ? const Color(0xFF5B9BFF) : null,
            onTap: () => toggle(i),
            padding: const EdgeInsets.all(RaSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: isSelected ? 0.26 : 0.16,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(item.$3, color: Colors.white, size: 25),
                ),
                const SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: RaSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Provider quote required',
                          style: TextStyle(
                            color: Color(0xFF9CC7FF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RaSpace.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: ValueKey(isSelected),
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          // Highlight ring when selected
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF9CC7FF)
                        : Colors.transparent,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final enabled = selected.isNotEmpty;
    final label = selected.isEmpty
        ? 'Select at least one issue'
        : 'Continue with ${selected.length} issue${selected.length == 1 ? '' : 's'}';
    return _Glass(
      radius: 26,

      padding: const EdgeInsets.fromLTRB(
        RaSpace.lg,
        RaSpace.md,
        RaSpace.lg,
        RaSpace.sm,
      ),
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                disabledForegroundColor: Colors.white54,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          TextButton.icon(
            icon: const Icon(Icons.help_outline, size: 20),
            label: const Text("I don't know the problem"),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
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
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _glassNavyTop,
      appBar: AppBar(
        title: const Text(
          'Assistance Type',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_glassNavyTop, _glassNavyMid, _glassBlueBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    RaSpace.xl,
                    topInset + RaSpace.md,
                    RaSpace.xl,
                    RaSpace.lg,
                  ),
                  children: [
                    _onGlass(context, const StepEyebrow(step: 1, of: 4)),
                    const SizedBox(height: RaSpace.lg),
                    const Text(
                      "What's the issue?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: RaSpace.sm),
                    const Text(
                      'Select every problem that applies. We will match a provider who supports all selected services.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    if (loadingDraft) ...[
                      const SizedBox(height: RaSpace.lg),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          color: Color(0xFF9CC7FF),
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ] else if (savedDraft != null) ...[
                      const SizedBox(height: RaSpace.lg),
                      _buildDraftCard(),
                    ],
                    const SizedBox(height: RaSpace.lg),
                    _onGlass(context, const SafetyBox()),
                    const SizedBox(height: RaSpace.lg),
                    for (var i = 0; i < items.length; i++) _buildIssueCard(i),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.md,
                  0,
                  RaSpace.md,
                  RaSpace.sm,
                ),
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
