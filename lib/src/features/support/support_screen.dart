part of '../../screens.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({
    super.key,
    required this.isProvider,
  });

  final bool isProvider;

  Future<void> showAppSupport(
    BuildContext context,
  ) async {
    final user = firebaseReady
        ? FirebaseAuth
            .instance.currentUser
        : null;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0D1D2B,
                  )
                : colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(
                      alpha: .24,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 21),

              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: colors.primary
                          .withValues(
                        alpha: .09,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .support_agent_outlined,
                      color: colors.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'App support',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 18,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color: colors
                                .onSurface,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Run quick checks or copy account diagnostics.',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 9.5,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _RaSupportSheetTile(
                icon: Icons.wifi_outlined,
                title:
                    'Connection checklist',
                subtitle:
                    'Internet, location and notifications',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  showInformation(
                    context,
                    'Connection Checklist',
                    '1. Confirm mobile data or Wi-Fi is connected.\n\n'
                        '2. Allow location permission when roadside assistance needs your position.\n\n'
                        '3. Allow notification permission for important request updates.\n\n'
                        '4. Restart RoadAssist and try again.',
                  );
                },
              ),

              const SizedBox(height: 9),

              _RaSupportSheetTile(
                icon:
                    Icons.copy_all_outlined,
                title:
                    'Copy account diagnostics',
                subtitle:
                    user?.email ??
                        'Guest session',
                onTap: () async {
                  final details =
                      'RoadAssist support details\n'
                      'Account: ${user?.email ?? 'Guest'}\n'
                      'Role: ${isProvider ? 'Provider' : 'Driver'}\n'
                      'Platform: ${Theme.of(context).platform.name}';

                  await Clipboard.setData(
                    ClipboardData(
                      text: details,
                    ),
                  );

                  if (sheetContext
                      .mounted) {
                    Navigator.pop(
                      sheetContext,
                    );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Support details copied.',
                        ),
                      ),
                    );
                  }
                },
              ),

              if (user != null) ...[
                const SizedBox(height: 9),

                _RaSupportSheetTile(
                  icon: Icons
                      .manage_accounts_outlined,
                  title:
                      'Account & Security',
                  subtitle:
                      'Password and account controls',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    push(
                      context,
                      const AccountSecurityScreen(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> showLocationSupport(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0D1D2B,
                  )
                : colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(
                      alpha: .24,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 21),

              Container(
                width: 50,
                height: 50,
                alignment:
                    Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .09),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons
                      .location_on_outlined,
                  color: colors.primary,
                ),
              ),

              const SizedBox(height: 13),

              Text(
                'Location & tracking',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'RoadAssist needs accurate location access during roadside assistance so providers can locate you and navigation can work correctly.',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  height: 1.45,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 17),

              FilledButton.icon(
                onPressed: () {
                  Geolocator
                      .openLocationSettings();
                },
                icon: const Icon(
                  Icons
                      .my_location_rounded,
                ),
                label: const Text(
                  'Open Location Settings',
                ),
              ),

              const SizedBox(height: 9),

              OutlinedButton.icon(
                onPressed: () {
                  Geolocator
                      .openAppSettings();
                },
                icon: const Icon(
                  Icons.settings_outlined,
                ),
                label: const Text(
                  'Open App Permissions',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showInformation(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .09),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: colors.primary,
            ),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text('Done'),
            ),
          ],
        );
      },
    );
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
          'Help & Support',
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
          34,
        ),
        children: [
          const _RaSupportHero(),

          const SizedBox(height: 27),

          const _RaSupportHeading(
            title: 'Roadside help',
            subtitle:
                'Quick access to safety and request-related support.',
          ),

          const SizedBox(height: 11),

          _RaSupportMenuGroup(
            children: [
              _RaSupportMenuTile(
                icon:
                    Icons.emergency_outlined,
                title:
                    'Emergency assistance',
                subtitle:
                    'Police, ambulance and trusted contact',
                tone: raDanger,
                onTap: () {
                  push(
                    context,
                    const EmergencyScreen(),
                  );
                },
              ),

              _RaSupportMenuTile(
                icon: Icons
                    .location_on_outlined,
                title:
                    'Location & tracking',
                subtitle:
                    'GPS, permissions and location settings',
                onTap: () {
                  showLocationSupport(
                    context,
                  );
                },
              ),

              _RaSupportMenuTile(
                icon:
                    Icons.receipt_long_outlined,
                title:
                    'Requests & service history',
                subtitle: isProvider
                    ? 'Review provider jobs and completed services'
                    : 'Review active and completed roadside requests',
                onTap: () {
                  if (isProvider) {
                    showInformation(
                      context,
                      'Provider Jobs',
                      'Open the Jobs tab to review active and completed RoadAssist services.',
                    );
                  } else {
                    push(
                      context,
                      const HistoryScreen(),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 27),

          const _RaSupportHeading(
            title: 'Account & app',
            subtitle:
                'Troubleshoot RoadAssist and manage account controls.',
          ),

          const SizedBox(height: 11),

          _RaSupportMenuGroup(
            children: [
              _RaSupportMenuTile(
                icon:
                    Icons.support_agent_outlined,
                title: 'App support',
                subtitle:
                    'Connection checks and diagnostics',
                onTap: () {
                  showAppSupport(
                    context,
                  );
                },
              ),

              _RaSupportMenuTile(
                icon:
                    Icons.privacy_tip_outlined,
                title:
                    'Privacy & Safety',
                subtitle:
                    'Permissions and information visibility',
                onTap: () {
                  push(
                    context,
                    PrivacySafetyScreen(
                      isProvider:
                          isProvider,
                    ),
                  );
                },
              ),

              if (signedIn)
                _RaSupportMenuTile(
                  icon: Icons
                      .manage_accounts_outlined,
                  title:
                      'Account & Security',
                  subtitle:
                      'Password and account controls',
                  onTap: () {
                    push(
                      context,
                      const AccountSecurityScreen(),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding:
                const EdgeInsets.all(14),
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
                      .verified_user_outlined,
                  color: colors.primary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Never share your RoadAssist password or verification codes when requesting support.',
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

class _RaSupportHero
    extends StatelessWidget {
  const _RaSupportHero();

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
                  Color(0xFF0A477D),
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
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons
                  .support_agent_outlined,
              size: 130,
              color: Colors.white
                  .withValues(alpha: .06),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Icon(
                  Icons
                      .support_agent_outlined,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'How can we help?',
                style:
                    GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: 290,
                child: Text(
                  'Find support for your roadside request, account, location, safety and app permissions.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .80,
                    ),
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaSupportHeading
    extends StatelessWidget {
  const _RaSupportHeading({
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
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 10,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaSupportMenuGroup
    extends StatelessWidget {
  const _RaSupportMenuGroup({
    required this.children,
  });

  final List<_RaSupportMenuTile>
      children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
                indent: 59,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .34,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RaSupportMenuTile
    extends StatelessWidget {
  const _RaSupportMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final activeTone =
        tone ?? colors.primary;

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: activeTone
              .withValues(alpha: .08),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: activeTone,
          size: 19,
        ),
      ),
      title: Text(
        title,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow:
            TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 8.7,
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

class _RaSupportSheetTile
    extends StatelessWidget {
  const _RaSupportSheetTile({
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

    return Material(
      color: colors
          .surfaceContainerHighest
          .withValues(alpha: .34),
      borderRadius:
          BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(13),
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
                  color: colors.primary,
                  size: 19,
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
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.7,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color:
                    colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}