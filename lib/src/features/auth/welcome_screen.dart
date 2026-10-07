part of '../../screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _continue(BuildContext context) {
    push(
      context,
      const RoleSelectionScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final background = dark
        ? const Color(0xFF04131F)
        : const Color(0xFFF5FAFE);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WelcomeReveal(
                index: 0,
                child: _WelcomeHeader(),
              ),

              const SizedBox(height: 22),

              const _WelcomeReveal(
                index: 1,
                child: _PremiumWelcomeHero(),
              ),

              const SizedBox(height: 28),

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
                            style: TextStyle(
                              color: colors.onSurface,
                            ),
                          ),
                          const TextSpan(
                            text: 'Our support.',
                            style: TextStyle(
                              color: Color(0xFF63B8FF),
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
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 23),

              const _WelcomeReveal(
                index: 3,
                child: _WelcomeFeatureGrid(),
              ),

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

              const _WelcomeReveal(
                index: 6,
                child: _WelcomeFooter(),
              ),
            ],
          ),
        ),
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
        const _WelcomeBrandLogo(
          size: 48,
        ),

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
                      style: TextStyle(
                        color: colors.onSurface,
                      ),
                    ),
                    const TextSpan(
                      text: 'Assist',
                      style: TextStyle(
                        color: Color(0xFF55B7F4),
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
                  color: colors.onSurfaceVariant,
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
      valueListenable:
          AppThemeController.mode,
      builder: (
        context,
        mode,
        child,
      ) {
        final dark =
            Theme.of(context).brightness ==
                Brightness.dark;

        return Container(
          height: 39,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0B2133,
                  )
                : Colors.white,
            borderRadius:
                BorderRadius.circular(999),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(
                      alpha: .15,
                    )
                  : const Color(
                      0xFFD4E1EB,
                    ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: dark ? .20 : .06,
                ),
                blurRadius: 16,
                offset: const Offset(
                  0,
                  5,
                ),
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
                selectedColor:
                    const Color(
                  0xFFFFB72B,
                ),
                onTap: () {
                  AppThemeController.setMode(
                    ThemeMode.light,
                  );
                },
              ),

              _WelcomeThemeButton(
                tooltip: 'Dark mode',
                icon: Icons.dark_mode_rounded,
                selected: dark,
                selectedColor:
                    const Color(
                  0xFF70B8FF,
                ),
                onTap: () {
                  AppThemeController.setMode(
                    ThemeMode.dark,
                  );
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
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(
                    alpha:
                        dark ? .25 : .16,
                  )
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? selectedColor
                : Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO IMAGE
// ============================================================

class _PremiumWelcomeHero extends StatelessWidget {
  const _PremiumWelcomeHero();

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: dark ? .30 : .11,
            ),
            blurRadius: 30,
            offset: const Offset(
              0,
              13,
            ),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.45,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/welcome_assistance.jpg',
                fit: BoxFit.cover,
                alignment:
                    const Alignment(
                  0,
                  .10,
                ),
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const _WelcomeHeroFallback();
                },
              ),

              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF041B2D,
                      ).withValues(
                        alpha:
                            dark ? .08 : .03,
                      ),
                      Colors.transparent,
                      const Color(
                        0xFF02101C,
                      ).withValues(
                        alpha:
                            dark ? .48 : .14,
                      ),
                    ],
                    stops: const [
                      0,
                      .52,
                      1,
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 14,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF031522,
                    ).withValues(
                      alpha: .76,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                    border: Border.all(
                      color: Colors.white
                          .withValues(
                        alpha: .15,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons
                            .shield_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        'ROADSIDE ASSISTANCE',
                        style:
                            GoogleFonts.plusJakartaSans(
                          color:
                              Colors.white,
                          fontSize: 8,
                          letterSpacing: .8,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeroFallback extends StatelessWidget {
  const _WelcomeHeroFallback();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          const _PremiumRoadPainter(),
      child: const SizedBox.expand(),
    );
  }
}

// ============================================================
// FALLBACK ROAD ART
// ============================================================

class _PremiumRoadPainter extends CustomPainter {
  const _PremiumRoadPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final width = size.width;
    final height = size.height;

    final rect =
        Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            const LinearGradient(
          begin: Alignment.topCenter,
          end:
              Alignment.bottomCenter,
          colors: [
            Color(0xFF071B34),
            Color(0xFF0B3E5D),
            Color(0xFF071522),
          ],
        ).createShader(rect),
    );

    final moonCenter = Offset(
      width * .77,
      height * .30,
    );

    canvas.drawCircle(
      moonCenter,
      height * .11,
      Paint()
        ..color =
            const Color(
          0xFFFFDB8A,
        ),
    );

    final mountains = Path()
      ..moveTo(
        0,
        height * .54,
      )
      ..lineTo(
        width * .18,
        height * .36,
      )
      ..lineTo(
        width * .35,
        height * .49,
      )
      ..lineTo(
        width * .53,
        height * .31,
      )
      ..lineTo(
        width * .69,
        height * .47,
      )
      ..lineTo(
        width,
        height * .30,
      )
      ..lineTo(
        width,
        height * .62,
      )
      ..lineTo(
        0,
        height * .62,
      )
      ..close();

    canvas.drawPath(
      mountains,
      Paint()
        ..color =
            const Color(
          0xFF0A2D49,
        ),
    );

    final road = Path()
      ..moveTo(
        width * .46,
        height * .55,
      )
      ..lineTo(
        width * .56,
        height * .55,
      )
      ..lineTo(
        width,
        height,
      )
      ..lineTo(
        0,
        height,
      )
      ..close();

    canvas.drawPath(
      road,
      Paint()
        ..color =
            const Color(
          0xFF07111D,
        ),
    );

    final lanePaint = Paint()
      ..color =
          Colors.white.withValues(
        alpha: .88,
      );

    for (var i = 0; i < 5; i++) {
      final y =
          height * (.60 + i * .085);

      final dashWidth =
          width * (.01 + i * .009);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              width * .51,
              y,
            ),
            width: dashWidth,
            height:
                height * .045,
          ),
          const Radius.circular(
            3,
          ),
        ),
        lanePaint,
      );
    }

    final carPaint = Paint()
      ..color =
          const Color(
        0xFF133A58,
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width * .12,
          height * .62,
          width * .29,
          height * .13,
        ),
        const Radius.circular(
          14,
        ),
      ),
      carPaint,
    );

    final lightPaint = Paint()
      ..color =
          const Color(
        0xFFFF473D,
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width * .15,
          height * .66,
          width * .055,
          height * .018,
        ),
        const Radius.circular(
          4,
        ),
      ),
      lightPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width * .33,
          height * .66,
          width * .055,
          height * .018,
        ),
        const Radius.circular(
          4,
        ),
      ),
      lightPaint,
    );

    final warningPaint = Paint()
      ..color =
          const Color(
        0xFFFF5A34,
      )
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin =
          StrokeJoin.round;

    final warning = Path()
      ..moveTo(
        width * .47,
        height * .78,
      )
      ..lineTo(
        width * .52,
        height * .66,
      )
      ..lineTo(
        width * .57,
        height * .78,
      )
      ..close();

    canvas.drawPath(
      warning,
      warningPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

// ============================================================
// FEATURE GRID
// ============================================================

class _WelcomeFeatureGrid extends StatelessWidget {
  const _WelcomeFeatureGrid();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WelcomeFeatureCard(
              icon:
                  Icons.request_quote_outlined,
              iconColor:
                  Color(0xFF64B5FF),
              iconBackground:
                  Color(0xFF103C71),
              title:
                  'Compare\nQuotes',
              description:
                  'Review provider offers and choose the right price.',
            ),
          ),

          SizedBox(width: 8),

          Expanded(
            child: _WelcomeFeatureCard(
              icon:
                  Icons.location_on_outlined,
              iconColor:
                  Color(0xFF49E1C3),
              iconBackground:
                  Color(0xFF0D514D),
              title:
                  'Real-Time\nUpdates',
              description:
                  'Track assistance while help is on the way.',
            ),
          ),

          SizedBox(width: 8),

          Expanded(
            child: _WelcomeFeatureCard(
              icon:
                  Icons.receipt_long_outlined,
              iconColor:
                  Color(0xFFB98AFF),
              iconBackground:
                  Color(0xFF42316A),
              title:
                  'Complete\nHistory',
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
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final dark =
        theme.brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        13,
        11,
        14,
      ),
      decoration: BoxDecoration(
        color: dark
            ? const Color(
                0xFF0C2032,
              )
            : colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? const Color(
                  0xFF203D55,
                )
              : colors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  dark ? .12 : .04,
            ),
            blurRadius: 15,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration:
                BoxDecoration(
              color: iconBackground,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 21,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.17,
              letterSpacing: -.25,
              fontWeight:
                  FontWeight.w700,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            description,
            maxLines: 4,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 10.1,
              height: 1.42,
              letterSpacing: -.05,
              fontWeight:
                  FontWeight.w400,
              color: colors
                  .onSurfaceVariant,
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
  const _WelcomePrimaryButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius:
          BorderRadius.circular(18),
      clipBehavior:
          Clip.antiAlias,
      child: Ink(
        padding:
            const EdgeInsets.symmetric(
          vertical: 16,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin:
                Alignment.centerLeft,
            end:
                Alignment.centerRight,
            colors: [
              Color(0xFF68BCFF),
              Color(0xFF2C94FA),
            ],
          ),
          borderRadius:
              BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF2B9AFF,
              ).withValues(
                alpha: .25,
              ),
              blurRadius: 18,
              offset:
                  const Offset(
                0,
                7,
              ),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 22,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Get Started',
                    textAlign:
                        TextAlign.center,
                    style:
                        GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      letterSpacing:
                          -.2,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          const Color(
                        0xFF031B2D,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                const Icon(
                  Icons
                      .arrow_forward_rounded,
                  color:
                      Color(
                    0xFF031B2D,
                  ),
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

class _WelcomeSecondaryButton
    extends StatelessWidget {
  const _WelcomeSecondaryButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final dark =
        theme.brightness ==
            Brightness.dark;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style:
            OutlinedButton.styleFrom(
          foregroundColor: dark
              ? const Color(
                  0xFF7BC3FF,
                )
              : theme
                  .colorScheme.primary,
          side: BorderSide(
            color: dark
                ? const Color(
                    0xFF4B6C87,
                  )
                : theme
                    .colorScheme
                    .outlineVariant,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
        child: Text(
          'I Already Have an Account',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            letterSpacing: -.15,
            fontWeight:
                FontWeight.w600,
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
    final colors =
        Theme.of(context)
            .colorScheme;

    final lineColor =
        colors.outlineVariant;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: lineColor,
          ),
        ),

        const SizedBox(width: 9),

        Icon(
          Icons.shield_outlined,
          size: 12,
          color:
              colors.onSurfaceVariant,
        ),

        const SizedBox(width: 7),

        Flexible(
          flex: 5,
          child: Text(
            'BUILT FOR ROADSIDE ASSISTANCE ACROSS SRI LANKA',
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 7,
              letterSpacing: 1.28,
              fontWeight:
                  FontWeight.w600,
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Container(
            height: 1,
            color: lineColor,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ENTRY ANIMATION
// ============================================================

class _WelcomeReveal extends StatelessWidget {
  const _WelcomeReveal({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(
      context,
    )) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 0,
        end: 1,
      ),
      duration: Duration(
        milliseconds:
            320 + index * 65,
      ),
      curve:
          Curves.easeOutCubic,
      child: child,
      builder: (
        context,
        value,
        child,
      ) {
        return Opacity(
          opacity: value,
          child:
              Transform.translate(
            offset: Offset(
              0,
              (1 - value) * 10,
            ),
            child: child,
          ),
        );
      },
    );
  }
}