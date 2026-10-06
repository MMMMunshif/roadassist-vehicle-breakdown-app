part of '../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
        final role = profileData?['role'] as String?;
        if (role == 'provider') {
          destination = const ProviderShell();
        } else if (role == 'driver') {
          destination = const DriverShell();
        } else {
          await FirebaseAuth.instance.signOut();
        }
        if (role == 'provider' || role == 'driver') {
          unawaited(DeviceService().registerCurrentDevice());
        }
      }
    } catch (_) {
      // A temporary network issue must not trap the user on the splash screen.
      destination = const WelcomeScreen();
    }
    final elapsed = DateTime.now().difference(startedAt);
    const minimumSplash = Duration(milliseconds: 700);
    if (elapsed < minimumSplash)
      await Future<void>.delayed(minimumSplash - elapsed);
    if (mounted) replace(context, destination);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [raNavyDeep, raNavy, raBlueDeep],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const BrandMark(size: 76, elevated: true),
            const SizedBox(height: RaSpace.xl),
            const Text(
              'RoadAssist',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: RaSpace.xs),
            Text(
              'Help when you need it most.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const Spacer(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Dot(active: true, onDark: true),
                Dot(onDark: true),
                Dot(onDark: true),
              ],
            ),
            const SizedBox(height: RaSpace.xxl),
            Text(
              "SRI LANKA'S ROADSIDE NETWORK",
              style: RaText.eyebrowOnDark.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
