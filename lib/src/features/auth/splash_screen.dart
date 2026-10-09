part of '../../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool startedAnimation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (startedAnimation) return;
    startedAnimation = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 1;
    } else {
      entrance.forward();
    }
  }

  @override
  void dispose() {
    entrance.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    final startedAt = DateTime.now();

    Widget destination = const WelcomeScreen();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final profile = await AuthService().getCurrentProfile();

        final profileData = profile.data();

        final role = accountLastRole(profileData);

        if (role == 'provider') {
          destination = enforceEmailVerification && !user.emailVerified
              ? const EmailVerificationScreen(role: 'provider')
              : const ProviderShell();
        } else if (role == 'driver') {
          destination = enforceEmailVerification && !user.emailVerified
              ? const EmailVerificationScreen(role: 'driver')
              : const DriverShell();
        } else {
          await FirebaseAuth.instance.signOut();
        }

        if ((role == 'provider' || role == 'driver') && user.emailVerified) {
          unawaited(DeviceService().registerCurrentDevice());
        }
      }
    } catch (_) {
      destination = const WelcomeScreen();
    }

    final elapsed = DateTime.now().difference(startedAt);

    const minimumSplash = Duration(milliseconds: 3200);

    if (elapsed < minimumSplash) {
      await Future<void>.delayed(minimumSplash - elapsed);
    }

    if (mounted) {
      replace(context, destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    TextStyle type(double size, double weight, Color color) => TextStyle(
      fontFamily: 'Manrope',
      fontVariations: [FontVariation('wght', weight)],
      fontSize: size,
      height: 1.4,
      color: color,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: entrance,
        builder: (context, _) {
          final t = reduced ? 1.0 : entrance.value;
          Widget reveal(double start, double end, Widget child) {
            final value = Curves.easeOutCubic.transform(
              ((t - start) / (end - start)).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 18),
                child: child,
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: CustomPaint(
                  painter: _SplashBackdrop(
                    colors: colors,
                    progress: t,
                    dark: dark,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: bounds.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 32,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              reveal(
                                0,
                                .42,
                                Transform.scale(
                                  scale:
                                      .88 +
                                      .12 * Curves.easeOutCubic.transform(t),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.primary.withValues(
                                          alpha: .13,
                                        ),
                                      ),
                                      color: colors.surface.withValues(
                                        alpha: .7,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: .09,
                                          ),
                                          blurRadius: 50,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const _WelcomeBrandLogo(size: 96),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              reveal(
                                .12,
                                .55,
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Road',
                                        style: TextStyle(
                                          color: colors.onSurface,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Assist',
                                        style: TextStyle(color: colors.primary),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: type(
                                    38,
                                    700,
                                    colors.onSurface,
                                  ).copyWith(letterSpacing: -1.2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              reveal(
                                .2,
                                .65,
                                Text(
                                  'WITH YOU, EVERY MILE',
                                  textAlign: TextAlign.center,
                                  style: type(
                                    10,
                                    600,
                                    colors.onSurfaceVariant,
                                  ).copyWith(letterSpacing: 2),
                                ),
                              ),
                              const SizedBox(height: 36),
                              reveal(
                                .3,
                                .78,
                                Text(
                                  'Roadside support,\nwhen it matters.',
                                  textAlign: TextAlign.center,
                                  style: type(
                                    24,
                                    600,
                                    colors.onSurface,
                                  ).copyWith(letterSpacing: -.5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              reveal(
                                .4,
                                .86,
                                Text(
                                  'Help. Clarity. Confidence.',
                                  textAlign: TextAlign.center,
                                  style: type(14, 400, colors.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 40),
                              reveal(
                                .45,
                                .95,
                                Column(
                                  children: [
                                    SizedBox(
                                      width: 112,
                                      child: LinearProgressIndicator(
                                        minHeight: 3,
                                        value: reduced
                                            ? null
                                            : t < 1
                                            ? t
                                            : null,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        backgroundColor: colors.primary
                                            .withValues(alpha: .1),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Preparing your experience',
                                      textAlign: TextAlign.center,
                                      style: type(
                                        11,
                                        400,
                                        colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),
                              reveal(
                                .5,
                                1,
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 15,
                                      color: colors.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Roadside assistance â€¢ Sri Lanka',
                                        textAlign: TextAlign.center,
                                        style: type(
                                          10,
                                          500,
                                          colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Quiet ambient light and a perspective road; never receives pointer events.
class _SplashBackdrop extends CustomPainter {
  const _SplashBackdrop({
    required this.colors,
    required this.progress,
    required this.dark,
  });
  final ColorScheme colors;
  final double progress;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(.35 - progress * .25, -.5),
          radius: 1.1,
          colors: [
            colors.primary.withValues(alpha: dark ? .12 : .07),
            colors.surface.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final road = Paint()
      ..color = colors.primary.withValues(alpha: .065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * .43, size.height * .7),
      Offset(-size.width * .1, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .57, size.height * .7),
      Offset(size.width * 1.1, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(_SplashBackdrop oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.dark != dark;
}
