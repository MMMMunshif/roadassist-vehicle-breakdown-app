part of '../screens.dart';

class LegacyWelcomeScreen extends StatelessWidget {
  const LegacyWelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const AssetSlot(
            height: 250,
            label: 'WELCOME HERO IMAGE\nSri Lankan coastal road',
            icon: Icons.landscape_outlined,
            assetPath: 'assets/images/welcome_road.jpg',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xl,
                RaSpace.xl,
                RaSpace.xl,
                RaSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: BrandMark(size: 44)),
                  const SizedBox(height: RaSpace.md),
                  const Text(
                    'Reliable Support in\nSri Lanka',
                    textAlign: TextAlign.center,
                    style: RaText.display,
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const Text(
                    'Professional vehicle recovery and repair services at your fingertips, wherever you are on the island.',
                    textAlign: TextAlign.center,
                    style: RaText.bodyMuted,
                  ),
                  const SizedBox(height: RaSpace.xxl),
                  const Text('WHY CHOOSE ROADASSIST', style: RaText.eyebrow),
                  const SizedBox(height: RaSpace.md),
                  const FeatureTile(
                    Icons.flash_on_outlined,
                    'Instant Assistance',
                    'Connect with nearby certified providers',
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const FeatureTile(
                    Icons.location_on_outlined,
                    'Real-time Tracking',
                    'Watch your provider arrive on a live route',
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const FeatureTile(
                    Icons.payments_outlined,
                    'Transparent Pricing',
                    'Review estimated costs before confirming',
                  ),
                  const SizedBox(height: RaSpace.xl),
                  FilledButton(
                    onPressed: () => push(context, const RoleSelectionScreen()),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Started'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
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
