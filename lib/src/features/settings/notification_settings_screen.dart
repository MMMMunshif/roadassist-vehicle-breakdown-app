part of '../../screens.dart';

class NotificationSettingsScreen
    extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
  });

  @override
  State<NotificationSettingsScreen>
      createState() =>
          _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool busy = false;

  String? result;
  bool? enabledResult;

  Future<void> update(
    bool enable,
  ) async {
    if (busy) {
      return;
    }

    setState(() {
      busy = true;
      result = null;
      enabledResult = null;
    });

    try {
      final devices =
          DeviceService();

      if (enable) {
        await devices
            .registerCurrentDevice(
          requestPermission: true,
        );
      } else {
        await devices
            .disableNotifications();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        enabledResult = enable;

        result = enable
            ? 'This device is registered for RoadAssist notifications.'
            : 'Push notifications are disabled for your account.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        enabledResult = null;

        result = error is StateError
            ? error.message.toString()
            : 'Could not update notifications. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          32,
        ),
        children: [
          const _RaNotificationHero(),
          const SizedBox(height: 24),
          const _RaNotificationHeading(
            title:
                'Important updates',
            subtitle:
                'RoadAssist notifications help you follow activity without keeping the app open.',
          ),
          const SizedBox(height: 10),
          const _RaNotificationFeatureCard(
            icon:
                Icons.request_quote_outlined,
            title:
                'Provider offers',
            subtitle:
                'Know when a provider sends a quote or revised repair cost.',
          ),
          const SizedBox(height: 8),
          const _RaNotificationFeatureCard(
            icon:
                Icons.route_outlined,
            title:
                'Service progress',
            subtitle:
                'Receive accepted, en-route, arrival and completion updates.',
          ),
          const SizedBox(height: 8),
          const _RaNotificationFeatureCard(
            icon: Icons
                .chat_bubble_outline_rounded,
            title:
                'Messages',
            subtitle:
                'Know when your driver or provider sends a new message.',
          ),
          const SizedBox(height: 24),
          _RaNotificationHeading(
            title:
                'This device',
            subtitle: signedIn
                ? 'Choose whether this device should receive RoadAssist push notifications.'
                : 'Sign in before changing notification settings.',
          ),
          const SizedBox(height: 10),
          _RaNotificationActionCard(
            icon: Icons
                .notifications_active_outlined,
            title:
                'Enable notifications',
            subtitle:
                'Allow this device to receive important RoadAssist activity.',
            tone:
                colors.primary,
            label:
                'Enable Notifications',
            filled: true,
            enabled:
                signedIn && !busy,
            onTap: () {
              update(true);
            },
          ),
          const SizedBox(height: 9),
          _RaNotificationActionCard(
            icon: Icons
                .notifications_off_outlined,
            title:
                'Disable notifications',
            subtitle:
                'Stop push notifications associated with your RoadAssist account.',
            tone:
                colors.onSurfaceVariant,
            label:
                'Disable Notifications',
            filled: false,
            enabled:
                signedIn && !busy,
            onTap: () {
              update(false);
            },
          ),
          if (busy) ...[
            const SizedBox(height: 15),
            const LinearProgressIndicator(
              minHeight: 3,
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 15),
            _RaNotificationResult(
              message: result!,
              success:
                  enabledResult != null,
              enabled:
                  enabledResult,
            ),
          ],
          const SizedBox(height: 19),
          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .06),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.devices_outlined,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If you use RoadAssist on multiple devices, notification permission may need to be enabled separately on each device.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 8.3,
                      height: 1.45,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaNotificationHero
    extends StatelessWidget {
  const _RaNotificationHero();

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF075A68),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons
                  .notifications_active_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay informed',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Receive important RoadAssist activity while the app is in the background.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 8.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaNotificationHeading
    extends StatelessWidget {
  const _RaNotificationHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaNotificationFeatureCard
    extends StatelessWidget {
  const _RaNotificationFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : colors.surface,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration:
                BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.8,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.8,
                    height: 1.4,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaNotificationActionCard
    extends StatelessWidget {
  const _RaNotificationActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final String label;

  final bool filled;
  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .055),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              tone.withValues(alpha: .15),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration:
                    BoxDecoration(
                  color: tone.withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 7.8,
                        height: 1.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filled)
            FilledButton.icon(
              onPressed:
                  enabled ? onTap : null,
              icon: Icon(icon),
              label: Text(label),
            )
          else
            OutlinedButton.icon(
              onPressed:
                  enabled ? onTap : null,
              icon: Icon(icon),
              label: Text(label),
            ),
        ],
      ),
    );
  }
}

class _RaNotificationResult
    extends StatelessWidget {
  const _RaNotificationResult({
    required this.message,
    required this.success,
    this.enabled,
  });

  final String message;
  final bool success;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final tone = success
        ? enabled == true
            ? raSuccess
            : colors.primary
        : colors.error;

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              tone.withValues(alpha: .17),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            success
                ? Icons
                    .check_circle_outline_rounded
                : Icons
                    .error_outline_rounded,
            color: tone,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 8.3,
                height: 1.4,
                color: colors
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}