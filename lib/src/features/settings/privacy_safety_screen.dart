part of '../../screens.dart';

class PrivacySafetyScreen extends StatelessWidget {
  const PrivacySafetyScreen({super.key, required this.isProvider});

  final bool isProvider;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Account Safety')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        const InfoStrip(
          icon: Icons.verified_user_outlined,
          title: 'Your information is protected',
          value: 'RoadAssist only shares details needed for active assistance.',
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Privacy controls'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconBadge(Icons.location_on_outlined),
                title: const Text('Location access', style: RaText.title),
                subtitle: const Text(
                  'Used for nearby matching and live assistance',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Geolocator.openAppSettings(),
              ),
              const Divider(height: 1, indent: 62),
              ListTile(
                leading: const IconBadge(Icons.lock_outline),
                title: const Text('Account & Security', style: RaText.title),
                subtitle: const Text(
                  'Password, verification and account deletion',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const AccountSecurityScreen()),
              ),
              const Divider(height: 1, indent: 62),
              ListTile(
                leading: const IconBadge(Icons.visibility_outlined),
                title: const Text(
                  'Who can see my details?',
                  style: RaText.title,
                ),
                subtitle: Text(
                  isProvider
                      ? 'Only drivers assigned to your active jobs can view service contact details.'
                      : 'Only the provider assigned to your active request can view the required contact and vehicle details.',
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Information visibility'),
                    content: Text(
                      isProvider
                          ? 'Drivers can access the provider information required for an accepted job. Other users cannot access your private account data.'
                          : 'Your assigned provider receives only the information required to complete the active roadside request. Never share your password or verification codes.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SafetyBox(),
      ],
    ),
  );
}
