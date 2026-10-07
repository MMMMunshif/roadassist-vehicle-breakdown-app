part of '../../app.dart';

class AppearanceScreen
    extends StatelessWidget {
  const AppearanceScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Appearance',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: ValueListenableBuilder<
          ThemeMode>(
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

              const SizedBox(height: 27),

              Text(
                'Choose your theme',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.35,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'RoadAssist can follow your device or stay in your preferred appearance.',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 10,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 15),

              _RaAppearanceOption(
                mode: ThemeMode.system,
                selectedMode:
                    selectedMode,
                icon: Icons
                    .settings_suggest_outlined,
                title:
                    'System default',
                subtitle:
                    'Match your phone appearance automatically',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.system,
                  );
                },
              ),

              const SizedBox(height: 10),

              _RaAppearanceOption(
                mode: ThemeMode.light,
                selectedMode:
                    selectedMode,
                icon:
                    Icons.light_mode_outlined,
                title: 'Light',
                subtitle:
                    'Bright, clear interface for daytime use',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.light,
                  );
                },
              ),

              const SizedBox(height: 10),

              _RaAppearanceOption(
                mode: ThemeMode.dark,
                selectedMode:
                    selectedMode,
                icon:
                    Icons.dark_mode_outlined,
                title: 'Dark',
                subtitle:
                    'Reduced glare for night-time viewing',
                onTap: () {
                  AppThemeController
                      .setMode(
                    ThemeMode.dark,
                  );
                },
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(
                  14,
                ),
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .06,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .visibility_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Your theme preference is saved on this device and updates RoadAssist immediately.',
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
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final modeLabel = switch (mode) {
      ThemeMode.system =>
        'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Container(
      padding: const EdgeInsets.all(18),
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
            BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(
                size: 38,
              ),

              const SizedBox(width: 9),

              Text(
                'RoadAssist',
                style:
                    GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
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
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),
                child: Text(
                  modeLabel,
                  style:
                      GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 19),

          Text(
            'Designed for the road,\nday or night.',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -.55,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Your selected appearance is applied across RoadAssist.',
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white
                  .withValues(alpha: .78),
              fontSize: 10,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? colors.primary
                      .withValues(
                      alpha: .55,
                    )
                  : colors.outlineVariant
                      .withValues(
                      alpha: .48,
                    ),
              width:
                  selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                          alpha: .45,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colors.primary
                      : colors
                          .onSurfaceVariant,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

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

              const SizedBox(width: 8),

              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 160,
                ),
                child: Icon(
                  selected
                      ? Icons
                          .check_circle_rounded
                      : Icons
                          .radio_button_off_rounded,
                  key: ValueKey(selected),
                  color: selected
                      ? colors.primary
                      : colors
                          .onSurfaceVariant,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}