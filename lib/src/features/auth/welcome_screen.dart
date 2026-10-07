part of '../../screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.xl,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            const _AuthWordmark(),

            const SizedBox(
              height: RaSpace.xl,
            ),

            const _AuthRoadArtwork(),

            const SizedBox(
              height: RaSpace.xxl,
            ),

            Text(
              'Your journey.\nOur support.',
              style: theme
                  .textTheme.headlineMedium
                  ?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            Text(
              'Request roadside assistance, compare provider quotes and follow your service progress from one place.',
              style: theme
                  .textTheme.bodyLarge
                  ?.copyWith(
                color:
                    colors.onSurfaceVariant,
                height: 1.55,
              ),
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            const _WelcomeBenefit(
              icon:
                  Icons.request_quote_outlined,
              title:
                  'Approve the price first',
              description:
                  'Compare available provider offers before choosing who handles your request.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            const _WelcomeBenefit(
              icon:
                  Icons.route_outlined,
              title:
                  'Follow active assistance',
              description:
                  'See meaningful job updates while your provider travels and works.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            const _WelcomeBenefit(
              icon:
                  Icons.receipt_long_outlined,
              title:
                  'Clear service history',
              description:
                  'Keep approved quotes, invoices and completed assistance records together.',
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => push(
                  context,
                  const RoleSelectionScreen(),
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                ),
                label: const Text(
                  'Get Started',
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => push(
                  context,
                  const RoleSelectionScreen(),
                ),
                child: const Text(
                  'I Already Have an Account',
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            Text(
              'Built for roadside assistance across Sri Lanka.',
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

class _WelcomeBenefit
    extends StatelessWidget {
  const _WelcomeBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 21,
              color:
                  colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme
                      .textTheme.titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}