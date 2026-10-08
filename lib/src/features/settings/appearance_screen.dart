part of '../../app.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({
    super.key,
  });

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
          'Appearance',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable:
            AppThemeController.mode,
        builder: (
          context,
          selectedMode,
          _,
        ) {
          return ListView(
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
              _RaAppearancePreview(
                mode: selectedMode,
              ),
              const SizedBox(height: 25),
              Text(
                'Choose your theme',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RoadAssist can follow your device or stay in your preferred appearance.',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  height: 1.45,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _RaAppearanceOption(
                mode: ThemeMode.system,
                selectedMode:
                    selectedMode,
                icon: Icons
                    .settings_suggest_outlined,
                title: 'System default',
                subtitle:
                    'Automatically follow your device appearance',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.system,
                  );
                },
              ),
              const SizedBox(height: 9),
              _RaAppearanceOption(
                mode: ThemeMode.light,
                selectedMode:
                    selectedMode,
                icon:
                    Icons.light_mode_outlined,
                title: 'Light',
                subtitle:
                    'Bright interface for daytime use',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.light,
                  );
                },
              ),
              const SizedBox(height: 9),
              _RaAppearanceOption(
                mode: ThemeMode.dark,
                selectedMode:
                    selectedMode,
                icon:
                    Icons.dark_mode_outlined,
                title: 'Dark',
                subtitle:
                    'Reduced glare for low-light viewing',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.dark,
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .06),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .devices_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your theme preference is saved on this device and applied immediately across RoadAssist.',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
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
          );
        },
      ),
    );
  }
}

class _RaAppearancePreview
    extends StatelessWidget {
  const _RaAppearancePreview({
    required this.mode,
  });

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final dark =
        theme.brightness ==
            Brightness.dark;

    final modeLabel =
        switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

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
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .directions_car_filled_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'RoadAssist',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),
                child: Text(
                  modeLabel,
                  style: theme
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Clear on the road,\nday or night.',
            style: theme
                .textTheme
                .headlineSmall
                ?.copyWith(
              color: Colors.white,
              fontWeight:
                  FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your selected appearance is applied throughout RoadAssist.',
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: Colors.white
                  .withValues(alpha: .78),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaAppearanceOption
    extends StatelessWidget {
  const _RaAppearanceOption({
    required this.mode,
    required this.selectedMode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ThemeMode mode;
  final ThemeMode selectedMode;

  final IconData icon;
  final String title;
  final String subtitle;

  final VoidCallback onTap;

  bool get selected =>
      mode == selectedMode;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final dark =
        theme.brightness ==
            Brightness.dark;

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? colors.primary
                  .withValues(alpha: .50)
              : colors.outlineVariant
                  .withValues(alpha: .45),
          width:
              selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: selected
                      ? colors.primary
                          .withValues(
                          alpha: .10,
                        )
                      : colors
                          .surfaceContainerHighest
                          .withValues(
                          alpha: .35,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? colors.primary
                      : colors
                          .onSurfaceVariant,
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
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons
                        .check_circle_rounded
                    : Icons
                        .radio_button_off_rounded,
                color: selected
                    ? colors.primary
                    : colors
                        .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}