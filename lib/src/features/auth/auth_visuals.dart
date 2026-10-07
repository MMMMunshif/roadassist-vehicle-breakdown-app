part of '../../screens.dart';

class _AuthWordmark extends StatelessWidget {
  const _AuthWordmark();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        'assets/images/roadassist_logo.png',
        width: 220,
        fit: BoxFit.contain,
        semanticLabel: 'RoadAssist',
      ),
    ),
  );
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