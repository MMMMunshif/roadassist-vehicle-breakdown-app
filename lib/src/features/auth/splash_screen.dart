part of '../../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.destinationLoader});

  @visibleForTesting
  final Future<Widget> Function()? destinationLoader;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<Widget> destination;
  bool started = false;
  Timer? minimumDisplay;
  final minimumReady = Completer<void>();

  @override
  void initState() {
    super.initState();
    destination = widget.destinationLoader?.call() ?? _resolveDestination();
    minimumDisplay = Timer(const Duration(milliseconds: 2500), () {
      if (!minimumReady.isCompleted) minimumReady.complete();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    unawaited(_openNextScreen());
  }

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
    final results = await Future.wait<Widget?>([
      destination,
      minimumReady.future.then<Widget?>((_) => null),
    ]);
    final target = results.first!;
    if (!mounted) return;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(
          name: target is WelcomeScreen
              ? '/welcome-from-splash'
              : '/startup-destination',
        ),
        transitionDuration: reduced
            ? Duration.zero
            : const Duration(milliseconds: 650),
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .025),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    minimumDisplay?.cancel();
    if (!minimumReady.isCompleted) minimumReady.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF041426) : const Color(0xFFF3FAFF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(painter: _RoleRoadPattern(dark: dark)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _WelcomeBrandLogo(size: 103),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Road',
                              style: TextStyle(color: colors.onSurface),
                            ),
                            const TextSpan(
                              text: 'Assist',
                              style: TextStyle(color: Color(0xFF129FEF)),
                            ),
                          ],
                        ),
                        style: roadAssistTextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Roadside help. Within reach.',
                      textAlign: TextAlign.center,
                      style: roadAssistTextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
