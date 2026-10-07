part of '../../screens.dart';

class RoleSelectionScreen
    extends StatelessWidget {
  const RoleSelectionScreen({
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
        title: const Text(
          'Choose Account Type',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.sm,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(
                RaSpace.xl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    const Color(0xFF007D70),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: .14),
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .shield_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(
                    height: RaSpace.lg,
                  ),
                  Text(
                    'How will you use RoadAssist?',
                    style: theme
                        .textTheme.headlineSmall
                        ?.copyWith(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the account type that matches what you need today.',
                    style: theme
                        .textTheme.bodyMedium
                        ?.copyWith(
                      color: Colors.white
                          .withValues(
                        alpha: .84,
                      ),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.xxl,
            ),

            _RoleSelectionCard(
              icon: Icons
                  .directions_car_filled_outlined,
              title: 'Driver',
              badge: 'GET ASSISTANCE',
              description:
                  'Request roadside help, manage saved vehicles, compare provider quotes and follow your active assistance.',
              highlights: const [
                'Multiple saved vehicles',
                'Provider quote comparison',
                'Live assistance updates',
              ],
              buttonLabel:
                  'Continue as Driver',
              onTap: () => push(
                context,
                const LoginScreen(
                  isProvider: false,
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            _RoleSelectionCard(
              icon: Icons
                  .home_repair_service_outlined,
              title: 'Service Provider',
              badge: 'PROFESSIONAL PORTAL',
              description:
                  'Receive matching roadside requests, send itemized quotes and manage active service jobs.',
              highlights: const [
                'Provider verification',
                'Request & quote management',
                'Active job workflow',
              ],
              buttonLabel:
                  'Continue as Provider',
              onTap: () => push(
                context,
                const LoginScreen(
                  isProvider: true,
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.xxl,
            ),

            Row(
              children: [
                Expanded(
                  child: Divider(
                    color:
                        colors.outlineVariant,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: RaSpace.md,
                  ),
                  child: Text(
                    'EMERGENCY ACCESS',
                    style: theme
                        .textTheme.labelSmall
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color:
                        colors.outlineVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            Container(
              padding: const EdgeInsets.all(
                RaSpace.md,
              ),
              decoration: BoxDecoration(
                color: colors.errorContainer
                    .withValues(alpha: .24),
                borderRadius:
                    BorderRadius.circular(17),
                border: Border.all(
                  color: colors.error
                      .withValues(alpha: .20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .emergency_outlined,
                        color: colors.error,
                      ),
                      const SizedBox(
                        width: RaSpace.sm,
                      ),
                      Expanded(
                        child: Text(
                          'Need urgent roadside access without signing in?',
                          style: theme
                              .textTheme.titleSmall
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: RaSpace.sm,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child:
                        OutlinedButton.icon(
                      style: OutlinedButton
                          .styleFrom(
                        foregroundColor:
                            colors.error,
                      ),
                      onPressed: () => replace(
                        context,
                        const DriverShell(),
                      ),
                      icon: const Icon(
                        Icons
                            .emergency_outlined,
                      ),
                      label: const Text(
                        'Continue with Emergency Guest Access',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.lg,
            ),

            Text(
              'By continuing, you agree to use RoadAssist responsibly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelectionCard
    extends StatelessWidget {
  const _RoleSelectionCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.highlights,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final List<String> highlights;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .65),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color:
                      colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color:
                      colors.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: theme
                          .textTheme.labelSmall
                          ?.copyWith(
                        color: colors.primary,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: theme
                          .textTheme.titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.lg),
          Text(
            description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          for (final item in highlights)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: raSuccess
                          .withValues(alpha: .10),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: raSuccess,
                    ),
                  ),
                  const SizedBox(
                    width: RaSpace.sm,
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style:
                          theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: RaSpace.md),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(
              Icons.arrow_forward_rounded,
            ),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}