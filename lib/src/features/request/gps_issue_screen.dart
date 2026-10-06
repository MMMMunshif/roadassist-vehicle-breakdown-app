part of '../../screens.dart';

class GpsIssueScreen extends StatefulWidget {
  const GpsIssueScreen({super.key});
  @override
  State<GpsIssueScreen> createState() => _GpsIssueScreenState();
}

class _GpsIssueScreenState extends State<GpsIssueScreen> {
  bool retrying = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Location Issue')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.md),
          decoration: BoxDecoration(
            color: raGoldPale,
            borderRadius: BorderRadius.circular(RaRadius.sm),
            border: Border.all(color: raGold.withValues(alpha: 0.4)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: raGold),
              SizedBox(width: RaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Location Accuracy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A4A00),
                      ),
                    ),
                    Text(
                      "We're having trouble pinpointing your exact location. This might delay help arriving.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF7A4A00)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(RaRadius.md),
          child: const SizedBox(height: 340, child: MapMock()),
        ),
        const SizedBox(height: RaSpace.xl),
        FilledButton.icon(
          onPressed: () async {
            setState(() => retrying = true);
            await Future<void>.delayed(const Duration(seconds: 1));
            if (mounted) setState(() => retrying = false);
          },
          icon: retrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh),
          label: Text(retrying ? 'Finding Location...' : 'Try Again'),
        ),
        const SizedBox(height: RaSpace.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Adjust Manually'),
        ),
        const SizedBox(height: RaSpace.sm),
        const Text(
          'Please refine your location before continuing.',
          textAlign: TextAlign.center,
          style: RaText.caption,
        ),
      ],
    ),
  );
}
