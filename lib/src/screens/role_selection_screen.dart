part of '../screens.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose Your Role')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          RaSpace.xl,
          RaSpace.lg,
          RaSpace.xl,
          RaSpace.xl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(RaSpace.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3F9FE), Color(0xFFE5F3FD)],
              ),
              borderRadius: BorderRadius.circular(RaRadius.lg),
              border: Border.all(color: raLine),
            ),
            child: const Row(
              children: [
                IconBadge(
                  Icons.shield_outlined,
                  size: 54,
                  iconSize: 27,
                  color: raBlue,
                  background: Colors.white,
                ),
                SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to RoadAssist', style: RaText.title),
                      SizedBox(height: RaSpace.xs),
                      Text(
                        'Secure roadside support for drivers and service professionals.',
                        style: RaText.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaSpace.xxl),
          const Text('Select your account type', style: RaText.headline),
          const SizedBox(height: RaSpace.xs),
          const Text(
            'Choose how you will use RoadAssist. You can sign in or create an account on the next step.',
            style: RaText.bodyMuted,
          ),
          const SizedBox(height: RaSpace.xl),
          RoleOptionCard(
            icon: Icons.directions_car_filled_outlined,
            title: 'Driver',
            badge: 'GET ASSISTANCE',
            description:
                'Request roadside help, track your provider live and manage vehicle details.',
            buttonLabel: 'Continue as Driver',
            onTap: () => push(context, const LoginScreen(isProvider: false)),
          ),
          const SizedBox(height: RaSpace.md),
          RoleOptionCard(
            icon: Icons.home_repair_service_outlined,
            title: 'Service Provider',
            badge: 'PROFESSIONAL PORTAL',
            description:
                'Receive nearby jobs, navigate to drivers and update service progress.',
            buttonLabel: 'Continue as Provider',
            onTap: () => push(context, const LoginScreen(isProvider: true)),
          ),
          const SizedBox(height: RaSpace.xxl),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RaSpace.md),
                child: Text(
                  'NEED URGENT HELP?',
                  style: RaText.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: RaSpace.sm),
          TextButton.icon(
            onPressed: () => replace(context, const DriverShell()),
            icon: const Icon(Icons.emergency_outlined, size: 18),
            label: const Text('Continue with emergency guest access'),
          ),
          const SizedBox(height: RaSpace.sm),
          const Text(
            'By continuing, you agree to use RoadAssist responsibly.',
            textAlign: TextAlign.center,
            style: RaText.caption,
          ),
        ],
      ),
    ),
  );
}
