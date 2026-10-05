part of '../screens.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool busy = false;
  String? result;
  Future<void> update(bool enable) async {
    setState(() => busy = true);
    try {
      final devices = DeviceService();
      if (enable) {
        await devices.registerCurrentDevice(requestPermission: true);
      } else {
        await devices.disableNotifications();
      }
      if (mounted)
        setState(
          () => result = enable
              ? 'This device is registered for notifications.'
              : 'Push notifications disabled for your account.',
        );
    } catch (error) {
      if (mounted)
        setState(
          () => result = error is StateError
              ? error.message.toString()
              : 'Could not update notifications. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Push notifications')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Get updates even when RoadAssist is in the background.',
          style: RaText.title,
        ),
        const SizedBox(height: 12),
        const Text(
          'Receive assistance requests, provider offers, price-change approvals, service updates and chat alerts. Enable notifications on each device you use.',
        ),
        const SizedBox(height: 20),
        if (!signedIn) const Text('Sign in to manage notifications.'),
        FilledButton.icon(
          onPressed: busy || !signedIn ? null : () => update(true),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Enable on this device'),
        ),
        OutlinedButton(
          onPressed: busy || !signedIn ? null : () => update(false),
          child: const Text('Disable for my account'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (result != null) Text(result!),
      ],
    ),
  );
}
