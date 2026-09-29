part of '../../screens.dart';

class AssistanceTypeScreen extends StatefulWidget {
  const AssistanceTypeScreen({super.key});

  @override
  State<AssistanceTypeScreen> createState() => _AssistanceTypeScreenState();
}

class _AssistanceTypeScreenState extends State<AssistanceTypeScreen> {
  int selected = -1;
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

  String formatEstimate(String issue) {
    final value = estimatedCostForIssue(issue).toString();
    final formatted = value.length > 3
        ? '${value.substring(0, value.length - 3)},${value.substring(value.length - 3)}'
        : value;
    return 'Estimated from Rs. $formatted';
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
                  "Select the type of help you need. We'll find the nearest certified specialist in your area.",
                  style: RaText.bodyMuted,
                ),
                const SizedBox(height: RaSpace.lg),
                const SafetyBox(),
                const SizedBox(height: RaSpace.md),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RaSpace.sm),
                    child: Card(
                      color: selected == i ? raPale : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RaRadius.md),
                        side: BorderSide(
                          color: selected == i ? raBlue : raLine,
                          width: selected == i ? 1.6 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RaSpace.md,
                          vertical: 4,
                        ),
                        onTap: () => setState(() => selected = i),
                        leading: IconBadge(items[i].$3),
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
                        trailing: Icon(
                          selected == i
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected == i ? raBlue : raFaint,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          BottomAction(
            label: 'Continue',
            enabled: selected >= 0,
            onTap: () => push(
              context,
              BreakdownDetailsScreen(issue: items[selected].$1),
            ),
          ),
        ],
      ),
    ),
  );
}
