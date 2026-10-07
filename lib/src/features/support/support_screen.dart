part of '../../screens.dart';

class SupportScreen
    extends StatelessWidget {
  const SupportScreen({
    super.key,
    required this.isProvider,
  });

  final bool isProvider;

  Future<void> showAppSupport(
    BuildContext context,
  ) async {
    final user =
        firebaseReady
            ? FirebaseAuth
                .instance
                .currentUser
            : null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        return Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            RaSpace.lg,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .support_agent_outlined,
                      color: colors
                          .onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(
                    width: RaSpace.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'RoadAssist App Support',
                          style: theme
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          'Run quick checks or manage your account securely.',
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              _SupportSheetTile(
                icon:
                    Icons.wifi_outlined,
                title:
                    'Connection checklist',
                subtitle:
                    'Internet, location and notification permissions',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  showInformation(
                    context,
                    'Connection Checklist',
                    '1. Confirm mobile data or Wi-Fi is connected.\n\n'
                        '2. Allow precise location permission when roadside assistance needs your exact position.\n\n'
                        '3. Allow notification permission for important request updates.\n\n'
                        '4. Restart RoadAssist and try again.',
                  );
                },
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              _SupportSheetTile(
                icon: Icons
                    .copy_all_outlined,
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
                    ScaffoldMessenger
                            .of(context)
                        .showSnackBar(
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
                const SizedBox(
                  height: RaSpace.sm,
                ),

                _SupportSheetTile(
                  icon: Icons
                      .manage_accounts_outlined,
                  title:
                      'Account & Security',
                  subtitle:
                      'Password, verification and account deletion',
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
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        return Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            RaSpace.lg,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(
                    17,
                  ),
                ),
                child: Icon(
                  Icons
                      .location_on_outlined,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(
                height: RaSpace.md,
              ),

              Text(
                'Location & Live Tracking',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              Text(
                'RoadAssist needs accurate location access while an assistance request is active so providers can locate you and navigation can work correctly.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  height: 1.45,
                ),
              ),

              const SizedBox(
                height: RaSpace.lg,
              ),

              FilledButton.icon(
                onPressed: () =>
                    Geolocator
                        .openLocationSettings(),
                icon: const Icon(
                  Icons
                      .location_on_outlined,
                ),
                label: const Text(
                  'Open Location Settings',
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              OutlinedButton.icon(
                onPressed: () =>
                    Geolocator
                        .openAppSettings(),
                icon: const Icon(
                  Icons
                      .settings_outlined,
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
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              Icons
                  .info_outline_rounded,
              color: colors
                  .onPrimaryContainer,
            ),
          ),
          title: Text(title),
          content: Text(
            message,
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hero(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            colors.primary,
            const Color(
              0xFF007D70,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -30,
            child: Icon(
              Icons
                  .support_agent_outlined,
              size: 135,
              color: Colors.white
                  .withValues(
                alpha: .07,
              ),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: const Icon(
                  Icons
                      .support_agent_outlined,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(
                height: RaSpace.lg,
              ),
              Text(
                'How can we help?',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                'Find support for your account, roadside request, safety and app permissions.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: Colors.white
                      .withValues(
                    alpha: .84,
                  ),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Help & Support',
        ),
      ),

      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          _hero(context),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          _SupportSectionHeader(
            title:
                'Quick support',
            subtitle:
                'Common support and safety actions.',
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          _SupportMenuGroup(
            children: [
              _SupportMenuTile(
                icon: Icons
                    .support_agent_outlined,
                title:
                    'RoadAssist App Support',
                subtitle:
                    'Account and app troubleshooting',
                onTap: () =>
                    showAppSupport(
                  context,
                ),
              ),
              _SupportMenuTile(
                icon: Icons
                    .emergency_outlined,
                title:
                    'Emergency Services',
                subtitle:
                    'Police emergency hotline 119',
                danger: true,
                onTap: () =>
                    showCallPrompt(
                  context,
                  name:
                      'Emergency Services',
                  number:
                      '119',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          _SupportSectionHeader(
            title:
                'Frequently asked questions',
            subtitle:
                'Guidance for common RoadAssist workflows.',
          ),

          const SizedBox(
            height: RaSpace.md,
          ),

          _SupportMenuGroup(
            children: [
              _SupportMenuTile(
                icon: Icons
                    .receipt_long_outlined,
                title: isProvider
                    ? 'How do I receive requests?'
                    : 'How do I request assistance?',
                subtitle: isProvider
                    ? 'Provider availability and request matching'
                    : 'Driver request process from start to provider selection',
                onTap: () =>
                    showInformation(
                  context,
                  isProvider
                      ? 'Receiving Requests'
                      : 'Requesting Assistance',
                  isProvider
                      ? 'Keep your provider status Active, allow location access and configure the services you offer. Matching nearby requests appear in real time.'
                      : 'Open Home, choose one or more assistance types, enter your vehicle and breakdown details, confirm your location, choose a provider option and review the request before submission.',
                ),
              ),
              _SupportMenuTile(
                icon: Icons
                    .location_on_outlined,
                title:
                    'Location & Live Tracking',
                subtitle:
                    'GPS, permissions and provider tracking',
                onTap: () =>
                    showLocationSupport(
                  context,
                ),
              ),
              _SupportMenuTile(
                icon: Icons
                    .lock_outline_rounded,
                title:
                    'Privacy & Account Safety',
                subtitle:
                    'Understand privacy and security controls',
                onTap: () =>
                    push(
                  context,
                  PrivacySafetyScreen(
                    isProvider:
                        isProvider,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: RaSpace.xxl,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              RaSpace.md,
            ),
            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(
                alpha: .42,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons
                      .verified_user_outlined,
                  size: 19,
                  color: theme
                      .colorScheme
                      .primary,
                ),
                const SizedBox(
                  width: RaSpace.sm,
                ),
                Expanded(
                  child: Text(
                    'For service-specific issues, use the relevant request or invoice screen so your report stays linked to the correct assistance job.',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      height: 1.4,
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

class _SupportSectionHeader
    extends StatelessWidget {
  const _SupportSectionHeader({
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
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: colors
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SupportMenuGroup
    extends StatelessWidget {
  const _SupportMenuGroup({
    required this.children,
  });

  final List<_SupportMenuTile>
      children;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .6,
          ),
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
                indent: 64,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SupportMenuTile
    extends StatelessWidget {
  const _SupportMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final color =
        danger
            ? colors.error
            : colors.primary;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: RaSpace.md,
        vertical: 6,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: .10,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: theme
            .textTheme.titleSmall
            ?.copyWith(
          fontWeight:
              FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
      ),
      trailing: const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap: onTap,
    );
  }
}

class _SupportSheetTile
    extends StatelessWidget {
  const _SupportSheetTile({
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
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(
                width: RaSpace.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}