part of '../../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.destinationLoader});

  /// Test seam for startup routing; production uses the existing auth gates.
  @visibleForTesting
  final Future<Widget> Function()? destinationLoader;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  late final handoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final Future<Widget> destination;
  bool started = false;
  @override
  void initState() {
    super.initState();
    destination = widget.destinationLoader?.call() ?? _resolveDestination();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    unawaited(_openNextScreen());
  }

  bool get reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  Future<Widget> _resolveDestination() async {
    Widget destination = const WelcomeScreen();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && GuestAssistanceService.hasGuestIdentity) {
        return const GuestAccessScreen();
      }
      if (user != null) {
        final profile = await AuthService().getCurrentProfile();

        final profileData = profile.data();

        final role = accountLastRole(profileData);

        if (role == 'provider') {
          destination =
              enforceEmailVerification &&
                  !await AuthService().isRoleEmailVerified(role!)
              ? const EmailVerificationScreen(role: 'provider')
              : const ProviderShell();
        } else if (role == 'driver') {
          destination =
              enforceEmailVerification &&
                  !await AuthService().isRoleEmailVerified(role!)
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

    return destination;
  }

  Future<void> _openNextScreen() async {
    final skip = reduced;
    final motion = skip ? Future<void>.value() : entrance.forward().orCancel;
    if (skip) entrance.value = 1;
    try {
      final results = await Future.wait<Object?>([
        destination,
        motion.then<Object?>((_) => null),
      ], eagerError: true);
      final target = results.first as Widget;
      if (!mounted) return;
      handoff.forward();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          settings: RouteSettings(
            name: target is WelcomeScreen
                ? '/welcome-from-splash'
                : '/startup-destination',
          ),
          transitionDuration: skip
              ? Duration.zero
              : const Duration(milliseconds: 750),
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
                child: child,
              ),
        ),
      );
    } on TickerCanceled {
      // Startup was removed before its finite motion completed.
    }
  }

  @override
  void dispose() {
    entrance.dispose();
    handoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme,
        dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF041426) : const Color(0xFFF7FBFF),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _RoleRoadPattern(dark: dark)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _AuthBackdrop(dark: dark, accent: const Color(0xFF43A7FF)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final w = bounds.maxWidth,
                    h = bounds.maxHeight,
                    mark = (w * .36).clamp(80.0, 150.0);
                return AnimatedBuilder(
                  animation: Listenable.merge([entrance, handoff]),
                  builder: (context, _) {
                    final t = entrance.value * 4200;
                    double step(double a, double b) => Curves.easeOutCubic
                        .transform(((t - a) / (b - a)).clamp(0.0, 1.0));
                    final logo = step(3050, 4070),
                        fade =
                            1 -
                            Curves.easeOutCubic.transform(
                              (handoff.value / .55).clamp(0.0, 1.0),
                            );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: _SplashConnectionPainter(
                                t: t,
                                start: Offset(
                                  w * .5,
                                  h * .48 - 60 * (1 - logo) + w * 144 / 390,
                                ),
                                end: Offset(w * .5, h * .16 + mark * .5),
                                fade: fade,
                                dark: dark,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: h * .48 - 60 * (1 - logo),
                          left: 0,
                          right: 0,
                          child: ExcludeSemantics(
                            child: Opacity(
                              opacity: fade,
                              child: RepaintBoundary(
                                child: SizedBox(
                                  height: w * 290 / 390,
                                  child: SplashRescueScene(
                                    progress: entrance.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: h * .16,
                          left: 20,
                          right: 20,
                          child: Column(
                            children: [
                              Opacity(
                                opacity: logo,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - logo) * 12),
                                  child: Hero(
                                    tag: 'opening-brand-mark',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: _WelcomeBrandLogo(size: mark),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Opacity(
                                opacity: step(3260, 4110),
                                child: Hero(
                                  tag: 'opening-brand-name',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      height: 46,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text.rich(
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
                                                style: TextStyle(
                                                  color: dark
                                                      ? const Color(0xFF55B7F4)
                                                      : const Color(0xFF14283F),
                                                ),
                                              ),
                                            ],
                                          ),
                                          style: roadAssistTextStyle(
                                            fontSize: 35,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Opacity(
                                opacity: step(3470, 4200) * fade,
                                child: Text(
                                  'A helping hand. Wherever you go.',
                                  textAlign: TextAlign.center,
                                  style: roadAssistTextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (h > 700)
                          Positioned(
                            top: 22,
                            left: 26,
                            child: Opacity(
                              opacity: fade,
                              child: Text(
                                'ROADASSIST / LK',
                                style: roadAssistTextStyle(
                                  fontSize: 8,
                                  letterSpacing: 1.8,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 26,
                          right: 26,
                          bottom: 24,
                          child: Opacity(
                            opacity: step(3650, 4200) * fade,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'ROADSIDE ASSISTANCE / SRI LANKA',
                                style: roadAssistTextStyle(
                                  fontSize: 8,
                                  letterSpacing: 1.7,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashConnectionPainter extends CustomPainter {
  const _SplashConnectionPainter({
    required this.t,
    required this.start,
    required this.end,
    required this.fade,
    required this.dark,
  });
  final double t, fade;
  final Offset start, end;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeOutCubic.transform(((t - 2750) / 900).clamp(0.0, 1.0));
    if (v == 0 || fade == 0) return;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * .15,
        start.dy - 35,
        size.width * .13,
        end.dy + 60,
        end.dx,
        end.dy,
      );
    final metric = path.computeMetrics().first;
    final alpha = (1 - ((t - 3650) / 550).clamp(0.0, 1.0) * .8) * fade;
    canvas.drawPath(
      metric.extractPath(0, metric.length * v),
      Paint()
        ..color = (dark ? const Color(0xFF8BDCFF) : const Color(0xFF188BC6))
            .withValues(alpha: alpha * .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashConnectionPainter old) =>
      t != old.t ||
      start != old.start ||
      end != old.end ||
      fade != old.fade ||
      dark != old.dark;
}
