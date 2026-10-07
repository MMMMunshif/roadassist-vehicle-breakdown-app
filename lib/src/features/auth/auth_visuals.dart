part of '../../screens.dart';

class _AuthWordmark extends StatelessWidget {
  const _AuthWordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                const Color(0xFF007D70),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: .14),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_road_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 11),
        Flexible(
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
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthRoadArtwork extends StatelessWidget {
  const _AuthRoadArtwork();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: 315,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/welcome_assistance.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, .15),
            semanticLabel:
                'Roadside technician helping a driver with a tyre',
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return Container(
                color: colors.primaryContainer,
                alignment: Alignment.center,
                child: Icon(
                  Icons.car_repair_outlined,
                  size: 72,
                  color: colors.onPrimaryContainer,
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .07),
                  Colors.black.withValues(alpha: .62),
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .34),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .14),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 21,
                  ),
                  SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: Text(
                      'Roadside support with clear provider quotes and live job updates.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}