import 'package:flutter/material.dart';

/// Presentation tokens only. Typography, brand artwork and business state are
/// deliberately supplied by the existing app and its widgets.
abstract final class RaPremiumPalette {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color surface(BuildContext context) =>
      dark(context) ? const Color(0xF20C263C) : const Color(0xF7FBFDFF);
  static Color edge(BuildContext context) =>
      dark(context) ? const Color(0xFF31536D) : const Color(0xFFD4E5F3);
  static LinearGradient panel(BuildContext context, {Color? base}) {
    final color = base ?? surface(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          (dark(context) ? const Color(0xFF448CCC) : Colors.white).withValues(
            alpha: dark(context) ? .12 : .65,
          ),
          color,
        ),
        color,
      ],
    );
  }
}

/// Uses a cheap static gradient instead of blurring every card in a long list.
/// Existing semantic colours, corners and borders remain explicit at call sites.
class RaPremiumDecoration extends BoxDecoration {
  RaPremiumDecoration(
    BuildContext context, {
    Color? color,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? backgroundBlendMode,
    BoxShape shape = BoxShape.rectangle,
  }) : super(
         color: color,
         gradient: gradient ?? RaPremiumPalette.panel(context, base: color),
         borderRadius: borderRadius,
         border: border ?? Border.all(color: RaPremiumPalette.edge(context)),
         boxShadow:
             boxShadow ??
             [
               BoxShadow(
                 color: Colors.black.withValues(
                   alpha: RaPremiumPalette.dark(context) ? .13 : .035,
                 ),
                 blurRadius: 18,
                 offset: const Offset(0, 6),
               ),
             ],
         image: image,
         backgroundBlendMode: backgroundBlendMode,
         shape: shape,
       );
}

/// A single sprite keeps service illustrations consistent across every journey.
class RaPremiumServiceIcon extends StatelessWidget {
  const RaPremiumServiceIcon({
    super.key,
    required this.icon,
    this.size = 36,
    this.color,
  });
  final IconData icon;
  final double size;
  final Color? color;
  static int? quadrant(IconData icon) {
    if ([
      Icons.car_repair_outlined,
      Icons.car_repair_rounded,
      Icons.build_outlined,
      Icons.build_rounded,
      Icons.build,
      Icons.handyman_outlined,
    ].contains(icon))
      return 0;
    if ([
      Icons.tire_repair_outlined,
      Icons.tire_repair_rounded,
      Icons.tire_repair,
    ].contains(icon))
      return 1;
    if ([
      Icons.battery_charging_full_rounded,
      Icons.battery_charging_full,
      Icons.battery_alert_outlined,
      Icons.battery_full,
    ].contains(icon))
      return 2;
    if ([
      Icons.local_shipping_outlined,
      Icons.local_shipping_rounded,
      Icons.car_crash_outlined,
      Icons.rv_hookup,
      Icons.fire_truck_outlined,
      Icons.fire_truck_rounded,
    ].contains(icon))
      return 3;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final index = quadrant(icon);
    if (index == null) return Icon(icon, size: size, color: color);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: -(index % 2) * size,
                top: -(index ~/ 2) * size,
                width: size * 2,
                height: size * 2,
                child: Image.asset(
                  'assets/images/premium_service_icons.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) =>
                      Icon(icon, size: size, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route motion runs once per navigation, never when Firestore updates a card.
class RaPremiumPageTransitions extends PageTransitionsBuilder {
  const RaPremiumPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context))
      return child;
    if (route.isFirst) return child;
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.035, .008),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

/// A short tactile response; no change to button text metrics or touch targets.
Widget raPremiumButtonFeedback(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final reduced =
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  return AnimatedScale(
    scale: !reduced && states.contains(WidgetState.pressed) ? .975 : 1,
    duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
    curve: Curves.easeOutCubic,
    child: child ?? const SizedBox.shrink(),
  );
}

/// A one-shot check for a server-confirmed state, never a substitute for it.
class RaPremiumSuccessMark extends StatelessWidget {
  const RaPremiumSuccessMark({super.key, this.size = 52, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2.2,
                color: tone,
                backgroundColor: tone.withValues(alpha: .12),
              ),
            ),
            Transform.scale(
              scale: .8 + value * .2,
              child: Opacity(
                opacity: value,
                child: Icon(Icons.check_rounded, size: size * .5, color: tone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData raServiceIconForLabel(String label) {
  final name = label.toLowerCase();
  if (name.contains('tyre') || name.contains('tire'))
    return Icons.tire_repair_outlined;
  if (name.contains('battery') || name.contains('jumpstart'))
    return Icons.battery_charging_full_rounded;
  if (name.contains('tow') || name.contains('recovery'))
    return Icons.fire_truck_outlined;
  return Icons.car_repair_outlined;
}

/// Secondary information shares one accessible disclosure across member screens.
/// Children stay mounted so collapsing never loses an in-progress form.
class RaDetailsDisclosure extends StatelessWidget {
  const RaDetailsDisclosure({
    super.key,
    required this.storageKey,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.info_outline,
    this.initiallyExpanded = false,
  });
  final String storageKey;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: RaPremiumDecoration(
        context,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey(storageKey),
        maintainState: true,
        initiallyExpanded: initiallyExpanded,
        expansionAnimationStyle: AnimationStyle(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
          reverseDuration: reduced
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(icon, size: 22, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: theme.textTheme.bodySmall),
        children: [child],
      ),
    );
  }
}

/// Keeps tab subtrees, scroll and forms alive while animating the visible tab.
class RaMemberTabStack extends StatefulWidget {
  const RaMemberTabStack({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  State<RaMemberTabStack> createState() => _RaMemberTabStackState();
}

class _RaMemberTabStackState extends State<RaMemberTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  bool get reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  @override
  void didUpdateWidget(covariant RaMemberTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (reduced) {
        motion.value = 1;
      } else {
        motion.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduced) motion.value = 1;
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(enabled: i == widget.index, child: widget.children[i]),
      ],
    );
    final curve = motion.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: Tween<double>(begin: .7, end: 1).animate(curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .012),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
