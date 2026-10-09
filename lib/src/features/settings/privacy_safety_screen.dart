part of '../../screens.dart';

class PrivacySafetyScreen extends StatelessWidget {
  const PrivacySafetyScreen({
    super.key,
    required this.isProvider,
  });

  final bool isProvider;

  void showVisibilityInfo(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (
        sheetContext,
      ) {
        final colors =
            Theme.of(sheetContext)
                .colorScheme;

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            22,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  Icons
                      .visibility_outlined,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Information visibility',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isProvider
                    ? 'Drivers can access the provider information required for an accepted job. Other users should not receive your private account information through the normal RoadAssist workflow.'
                    : 'Your assigned provider receives information required to complete the active roadside request, such as relevant vehicle, contact and request details. Never share your password or verification codes.',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 9,
                  height: 1.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 17),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    sheetContext,
                  );
                },
                child:
                    const Text('Got It'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> openLocationSettings(
    BuildContext context,
  ) async {
    final opened =
        await Geolocator.openAppSettings();

    if (!opened &&
        context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open app settings on this device.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return RaScaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Privacy & Safety',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
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
          const _RaPrivacyHero(),
          const SizedBox(height: 24),
          const _RaPrivacyHeading(
            title:
                'Privacy controls',
            subtitle:
                'Review permissions and understand how RoadAssist uses operational information.',
          ),
          const SizedBox(height: 10),
          _RaPrivacyMenuCard(
            children: [
              _RaPrivacyTile(
                icon:
                    Icons.location_on_outlined,
                title:
                    'Location access',
                subtitle:
                    'Used when location is needed for roadside matching, navigation and active assistance',
                onTap: () {
                  openLocationSettings(
                    context,
                  );
                },
              ),
              _RaPrivacyTile(
                icon: Icons
                    .notifications_outlined,
                title:
                    'Notification access',
                subtitle:
                    'Manage background request and service alerts',
                onTap: () {
                  push(
                    context,
                    const NotificationSettingsScreen(),
                  );
                },
              ),
              _RaPrivacyTile(
                icon:
                    Icons.lock_outline_rounded,
                title:
                    'Account & Security',
                subtitle:
                    'Password recovery, verification and account deletion',
                onTap: () {
                  push(
                    context,
                    const AccountSecurityScreen(),
                  );
                },
              ),
              _RaPrivacyTile(
                icon:
                    Icons.visibility_outlined,
                title:
                    'Who can see my details?',
                subtitle: isProvider
                    ? 'Understand what an assigned driver may need to see'
                    : 'Understand what an assigned provider may need to see',
                onTap: () {
                  showVisibilityInfo(
                    context,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _RaPrivacyHeading(
            title:
                'Roadside safety',
            subtitle:
                'Personal safety takes priority over completing an app workflow.',
          ),
          const SizedBox(height: 10),
          const _RaPrivacySafetyCard(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                push(
                  context,
                  const EmergencyScreen(),
                );
              },
              icon: const Icon(
                Icons.emergency_outlined,
              ),
              label: const Text(
                'Emergency Contacts',
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _RaPrivacyInfoCard(),
        ],
      ),
    );
  }
}

class _RaPrivacyHero
    extends StatelessWidget {
  const _RaPrivacyHero();

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
          begin:
              Alignment.topLeft,
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
                  .verified_user_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Your information matters',
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
                  'RoadAssist uses information needed to support roadside assistance and account security.',
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

class _RaPrivacyHeading
    extends StatelessWidget {
  const _RaPrivacyHeading({
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

class _RaPrivacyMenuCard
    extends StatelessWidget {
  const _RaPrivacyMenuCard({
    required this.children,
  });

  final List<_RaPrivacyTile> children;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0;
              index < children.length;
              index++) ...[
            children[index],
            if (index !=
                children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .35,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RaPrivacyTile
    extends StatelessWidget {
  const _RaPrivacyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 3,
      ),
      leading: Container(
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
          color: colors.primary,
          size: 19,
        ),
      ),
      title: Text(
        title,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 9.7,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow:
            TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 7.5,
          height: 1.35,
          color:
              colors.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color:
            colors.onSurfaceVariant,
      ),
    );
  }
}

class _RaPrivacySafetyCard
    extends StatelessWidget {
  const _RaPrivacySafetyCard();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            raGold.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              raGold.withValues(alpha: .20),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 41,
            height: 41,
            decoration:
                BoxDecoration(
              color: raGold
                  .withValues(alpha: .12),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons
                  .health_and_safety_outlined,
              color: raGold,
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
                  'Stay safe first',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Move away from active traffic when it is safe to do so. For immediate danger, contact emergency services before continuing with RoadAssist.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8,
                    height: 1.45,
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

class _RaPrivacyInfoCard
    extends StatelessWidget {
  const _RaPrivacyInfoCard();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .28),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .info_outline_rounded,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Never share your RoadAssist password, verification code or authentication credentials with a driver, provider or support contact.',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 8,
                height: 1.45,
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