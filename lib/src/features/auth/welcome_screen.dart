part of '../../screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _continue(BuildContext context) {
    push(context, const RoleSelectionScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final background = dark ? const Color(0xFF04131F) : const Color(0xFFF5FAFE);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Image.asset(
              dark
                  ? 'assets/images/welcome_background.png'
                  : 'assets/images/welcome_background_light.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: background),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          background.withValues(alpha: .20),
                          background.withValues(alpha: .08),
                          background.withValues(alpha: .90),
                          background,
                        ]
                      : [
                          background.withValues(alpha: .10),
                          background.withValues(alpha: .02),
                          background.withValues(alpha: .92),
                          background,
                        ],
                  stops: const [0, .28, .52, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WelcomeReveal(index: 0, child: _WelcomeHeader()),

                  // Keep the roadside scene visible behind the welcome content.
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * .28).clamp(
                      120.0,
                      260.0,
                    ),
                  ),

                  _WelcomeReveal(
                    index: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Your journey.\n',
                                style: TextStyle(color: colors.onSurface),
                              ),
                              TextSpan(
                                text: 'Our support.',
                                style: TextStyle(
                                  color: dark
                                      ? const Color(0xFF63B8FF)
                                      : const Color(0xFF14283F),
                                ),
                              ),
                            ],
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 35,
                            height: 1.07,
                            letterSpacing: -1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          'Request roadside assistance, compare provider '
                          'quotes and follow your service progress from one place.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            height: 1.58,
                            letterSpacing: -.15,
                            fontWeight: FontWeight.w400,
                            color: theme.brightness == Brightness.dark
                                ? colors.onSurfaceVariant
                                : const Color(0xFF263B50),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 23),

                  const _WelcomeReveal(index: 3, child: _WelcomeFeatureGrid()),

                  const SizedBox(height: 23),

                  _WelcomeReveal(
                    index: 4,
                    child: _WelcomePrimaryButton(
                      onTap: () => _continue(context),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _WelcomeReveal(
                    index: 5,
                    child: _WelcomeSecondaryButton(
                      onTap: () => _continue(context),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const _WelcomeReveal(index: 6, child: _WelcomeFooter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        const _WelcomeBrandLogo(size: 48),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Road',
                      style: TextStyle(color: colors.onSurface),
                    ),
                    TextSpan(
                      text: 'Assist',
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF55B7F4)
                            : const Color(0xFF14283F),
                      ),
                    ),
                  ],
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  height: 1,
                  letterSpacing: -.7,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'ON THE ROAD WITH YOU',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 7.8,
                  height: 1.2,
                  letterSpacing: 1.75,
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? colors.onSurfaceVariant
                      : const Color(0xFF263B50),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        const _WelcomeThemeToggle(),
      ],
    );
  }
}

// ============================================================
// PREMIUM ROADASSIST LOGO
// ============================================================

class _WelcomeBrandLogo extends StatelessWidget {
  const _WelcomeBrandLogo({this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => BrandMark(size: size);
}

// ============================================================
// LIGHT / DARK THEME SWITCH
// ============================================================

class _WelcomeThemeToggle extends StatelessWidget {
  const _WelcomeThemeToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          height: 39,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0B2133) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .15)
                  : const Color(0xFFD4E1EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .20 : .06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WelcomeThemeButton(
                tooltip: 'Light mode',
                icon: Icons.light_mode_rounded,
                selected: !dark,
                selectedColor: const Color(0xFFFFB72B),
                onTap: () {
                  AppThemeController.setMode(ThemeMode.light);
                },
              ),

              _WelcomeThemeButton(
                tooltip: 'Dark mode',
                icon: Icons.dark_mode_rounded,
                selected: dark,
                selectedColor: const Color(0xFF70B8FF),
                onTap: () {
                  AppThemeController.setMode(ThemeMode.dark);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeThemeButton extends StatelessWidget {
  const _WelcomeThemeButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: dark ? .25 : .16)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? selectedColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO IMAGE
// ============================================================

class _WelcomeFeatureGrid extends StatelessWidget {
  const _WelcomeFeatureGrid();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WelcomeFeatureCard(
              icon: Icons.request_quote_outlined,
              iconColor: Color(0xFF64B5FF),
              iconBackground: Color(0xFF103C71),
              title: 'Compare\nQuotes',
              description: 'Review provider offers and choose the right price.',
            ),
          ),

          SizedBox(width: 8),

          Expanded(
            child: _WelcomeFeatureCard(
              icon: Icons.location_on_outlined,
              iconColor: Color(0xFF49E1C3),
              iconBackground: Color(0xFF0D514D),
              title: 'Real-Time\nUpdates',
              description: 'Track assistance while help is on the way.',
            ),
          ),

          SizedBox(width: 8),

          Expanded(
            child: _WelcomeFeatureCard(
              icon: Icons.receipt_long_outlined,
              iconColor: Color(0xFFB98AFF),
              iconBackground: Color(0xFF42316A),
              title: 'Complete\nHistory',
              description:
                  'Keep quotes, invoices and service records together.',
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFeatureCard extends StatelessWidget {
  const _WelcomeFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 11, 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0C2032) : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF203D55) : colors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .12 : .04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.17,
              letterSpacing: -.25,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.1,
              height: 1.42,
              letterSpacing: -.05,
              fontWeight: FontWeight.w400,
              color: theme.brightness == Brightness.dark
                  ? colors.onSurfaceVariant
                  : const Color(0xFF263B50),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRIMARY BUTTON
// ============================================================

class _WelcomePrimaryButton extends StatelessWidget {
  const _WelcomePrimaryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF68BCFF), Color(0xFF2C94FA)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B9AFF).withValues(alpha: .25),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Get Started',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      letterSpacing: -.2,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF031B2D),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF031B2D),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECONDARY BUTTON
// ============================================================

class _WelcomeSecondaryButton extends StatelessWidget {
  const _WelcomeSecondaryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: dark
              ? const Color(0xFF7BC3FF)
              : const Color(0xFF14283F),
          side: BorderSide(
            color: dark
                ? const Color(0xFF4B6C87)
                : theme.colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          'I Already Have an Account',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            letterSpacing: -.15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FOOTER
// ============================================================

class _WelcomeFooter extends StatelessWidget {
  const _WelcomeFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final lineColor = colors.outlineVariant;

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: lineColor)),

        const SizedBox(width: 9),

        Icon(Icons.shield_outlined, size: 12, color: colors.onSurfaceVariant),

        const SizedBox(width: 7),

        Flexible(
          flex: 5,
          child: Text(
            'BUILT FOR ROADSIDE ASSISTANCE ACROSS SRI LANKA',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 7,
              letterSpacing: 1.28,
              fontWeight: FontWeight.w600,
              color: theme.brightness == Brightness.dark
                  ? colors.onSurfaceVariant
                  : const Color(0xFF263B50),
            ),
          ),
        ),

        const SizedBox(width: 9),

        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }
}

// ============================================================
// ENTRY ANIMATION
// ============================================================

class _WelcomeReveal extends StatelessWidget {
  const _WelcomeReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 65),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
    );
  }
}
