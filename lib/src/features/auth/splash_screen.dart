part of '../../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    final startedAt = DateTime.now();

    Widget destination =
        const WelcomeScreen();

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user != null) {
        final profile =
            await AuthService()
                .getCurrentProfile();

        final profileData =
            profile.data();

        final role =
            profileData?['role']
                as String?;

        if (role == 'provider') {
          destination =
              const ProviderShell();
        } else if (role ==
            'driver') {
          destination =
              const DriverShell();
        } else {
          await FirebaseAuth
              .instance
              .signOut();
        }

        if (role == 'provider' ||
            role == 'driver') {
          unawaited(
            DeviceService()
                .registerCurrentDevice(),
          );
        }
      }
    } catch (_) {
      destination =
          const WelcomeScreen();
    }

    final elapsed =
        DateTime.now()
            .difference(startedAt);

    const minimumSplash =
        Duration(milliseconds: 700);

    if (elapsed <
        minimumSplash) {
      await Future<void>.delayed(
        minimumSplash - elapsed,
      );
    }

    if (mounted) {
      replace(
        context,
        destination,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            bounds,
          ) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      bounds.maxHeight,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    28,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const _AuthWordmark(),

                      const SizedBox(
                        height: 34,
                      ),

                      Container(
                        width: 126,
                        height: 126,
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            begin: Alignment
                                .topLeft,
                            end: Alignment
                                .bottomRight,
                            colors: [
                              colors.primary,
                              const Color(
                                0xFF007D70,
                              ),
                            ],
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            38,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors
                                  .primary
                                  .withValues(
                                alpha: .18,
                              ),
                              blurRadius: 34,
                              offset:
                                  const Offset(
                                0,
                                15,
                              ),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons
                              .add_road_rounded,
                          color: Colors.white,
                          size: 62,
                        ),
                      ),

                      const SizedBox(
                        height: 32,
                      ),

                      Text(
                        'Roadside support,\nwhen it matters.',
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(
                        height: RaSpace.sm,
                      ),

                      Text(
                        'Preparing your RoadAssist experience…',
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(
                        height: 32,
                      ),

                      SizedBox(
                        width: 110,
                        child:
                            LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius:
                              BorderRadius.circular(
                            999,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons
                                .shield_outlined,
                            size: 15,
                            color: colors
                                .onSurfaceVariant,
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Text(
                            'ROADSIDE SUPPORT • SRI LANKA',
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                              letterSpacing:
                                  .8,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}