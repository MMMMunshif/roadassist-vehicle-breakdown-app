part of '../../screens.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.isProvider});

  final bool isProvider;

  Future<void> showAppSupport(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            0,
            RaSpace.xl,
            RaSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('RoadAssist App Support', style: RaText.headline),
              const SizedBox(height: RaSpace.xs),
              Text(
                'Run quick checks or manage your account securely.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: RaSpace.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(Icons.wifi_outlined),
                title: const Text('Connection checklist'),
                subtitle: const Text(
                  'Internet, location and notification permissions',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showInformation(
                    context,
                    'Connection Checklist',
                    '1. Confirm mobile data or Wi-Fi is connected.\n\n2. Allow precise location permission.\n\n3. Allow notification permission.\n\n4. Restart RoadAssist and try again.',
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(Icons.copy_all_outlined),
                title: const Text('Copy account diagnostics'),
                subtitle: Text(user?.email ?? 'Guest session'),
                onTap: () async {
                  final details =
                      'RoadAssist support details\nAccount: ${user?.email ?? 'Guest'}\nRole: ${isProvider ? 'Provider' : 'Driver'}\nPlatform: ${Theme.of(context).platform.name}';
                  await Clipboard.setData(ClipboardData(text: details));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support details copied.')),
                    );
                  }
                },
              ),
              if (user != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconBadge(Icons.manage_accounts_outlined),
                  title: const Text('Account & Security'),
                  subtitle: const Text(
                    'Password, verification and account deletion',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    push(context, const AccountSecurityScreen());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showLocationSupport(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            0,
            RaSpace.xl,
            RaSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Location & Live Tracking', style: RaText.headline),
              const SizedBox(height: RaSpace.sm),
              const Text(
                'Precise location must be enabled while an assistance request is active.',
              ),
              const SizedBox(height: RaSpace.lg),
              FilledButton.icon(
                onPressed: () => Geolocator.openLocationSettings(),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Open Location Settings'),
              ),
              const SizedBox(height: RaSpace.sm),
              OutlinedButton.icon(
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open App Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showInformation(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [Color(0xFF182733), Color(0xFF203746)]
                  : const [Color(0xFFEAF5FE), Color(0xFFF7FBFF)],
            ),
            borderRadius: BorderRadius.circular(RaRadius.lg),
            border: Border.all(color: raLine),
          ),
          child: Column(
            children: [
              const IconBadge(
                Icons.support_agent_outlined,
                size: 58,
                iconSize: 29,
              ),
              const SizedBox(height: RaSpace.md),
              Text(
                'How can we help?',
                style: RaText.headline.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: RaSpace.xs),
              Text(
                'RoadAssist support and safety information is available here.',
                textAlign: TextAlign.center,
                style: RaText.bodyMuted.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Quick Support'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconBadge(Icons.support_agent_outlined),
                title: const Text(
                  'RoadAssist App Support',
                  style: RaText.title,
                ),
                subtitle: const Text(
                  'Account and app troubleshooting',
                  style: RaText.caption,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppSupport(context),
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: const IconBadge(
                  Icons.emergency_outlined,
                  color: raDanger,
                  background: raDangerPale,
                ),
                title: const Text('Emergency Services', style: RaText.title),
                subtitle: const Text(
                  'Police emergency hotline 119',
                  style: RaText.caption,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showCallPrompt(
                  context,
                  name: 'Emergency Services',
                  number: '119',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Frequently Asked Questions'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: raBlue),
                title: Text(
                  isProvider
                      ? 'How do I receive requests?'
                      : 'How do I request assistance?',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showInformation(
                  context,
                  isProvider ? 'Receiving Requests' : 'Requesting Assistance',
                  isProvider
                      ? 'Keep your provider status Active, allow location access and configure the services you offer. Matching nearby requests appear in real time.'
                      : 'Open Home, choose an assistance type, enter vehicle details, confirm your location and select an available provider.',
                ),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: raBlue),
                title: const Text(
                  'Location and live tracking',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLocationSupport(context),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: raBlue),
                title: const Text(
                  'Privacy and account safety',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    push(context, PrivacySafetyScreen(isProvider: isProvider)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
