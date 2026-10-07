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
    if (busy) return;

    setState(() {
      busy = true;
      result = null;
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

      if (!mounted) return;

      setState(() {
        enabledResult = enable;

        result = enable
            ? 'This device is registered for RoadAssist notifications.'
            : 'Push notifications are disabled for your account.';
      });
    } catch (error) {
      if (!mounted) return;

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Push Notifications',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
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

          const SizedBox(height: 27),

          Text(
            'What you’ll receive',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 11),

          const _RaNotificationFeatures(),

          const SizedBox(height: 25),

          Text(
            'This device',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            signedIn
                ? 'Choose whether this device should receive RoadAssist push notifications.'
                : 'Sign in before changing notification settings.',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 10,
              height: 1.4,
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          _RaNotificationActionCard(
            icon: Icons
                .notifications_active_outlined,
            title:
                'Enable notifications',
            subtitle:
                'Register this device for assistance, chat and service updates.',
            tone: colors.primary,
            buttonLabel:
                'Enable on this device',
            filled: true,
            enabled:
                !busy && signedIn,
            onTap: () {
              update(true);
            },
          ),

          const SizedBox(height: 10),

          _RaNotificationActionCard(
            icon: Icons
                .notifications_off_outlined,
            title:
                'Disable notifications',
            subtitle:
                'Stop push notifications associated with your account.',
            tone:
                colors.onSurfaceVariant,
            buttonLabel:
                'Disable for my account',
            filled: false,
            enabled:
                !busy && signedIn,
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

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(
              14,
            ),
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .06),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons
                      .devices_outlined,
                  color: colors.primary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'If you use RoadAssist on multiple devices, enable notifications separately on each device.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 10,
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
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B477D),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
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

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay updated',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Receive important RoadAssist activity even when the app is in the background.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .80,
                    ),
                    fontSize: 10,
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

class _RaNotificationFeatures
    extends StatelessWidget {
  const _RaNotificationFeatures();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _RaNotificationFeature(
          icon: Icons
              .request_quote_outlined,
          title:
              'Provider offers',
          subtitle:
              'Know when providers send prices or revisions.',
        ),
        SizedBox(height: 9),
        _RaNotificationFeature(
          icon:
              Icons.route_outlined,
          title:
              'Service progress',
          subtitle:
              'Follow accepted, en-route, arrival and completion updates.',
        ),
        SizedBox(height: 9),
        _RaNotificationFeature(
          icon: Icons
              .chat_bubble_outline_rounded,
          title: 'Messages',
          subtitle:
              'Get notified when your provider or driver sends a message.',
        ),
      ],
    );
  }
}

class _RaNotificationFeature
    extends StatelessWidget {
  const _RaNotificationFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(17),
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
            decoration: BoxDecoration(
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

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.8,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.8,
                    height: 1.35,
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
    required this.buttonLabel,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final String buttonLabel;

  final bool filled;
  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .055),
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color:
              tone.withValues(alpha: .14),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(alpha: .10),
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

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9,
                        height: 1.35,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            child: filled
                ? FilledButton.icon(
                    onPressed:
                        enabled ? onTap : null,
                    icon: Icon(icon),
                    label:
                        Text(buttonLabel),
                  )
                : OutlinedButton.icon(
                    onPressed:
                        enabled ? onTap : null,
                    icon: Icon(icon),
                    label:
                        Text(buttonLabel),
                  ),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              tone.withValues(alpha: .16),
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
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 10,
                height: 1.4,
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}