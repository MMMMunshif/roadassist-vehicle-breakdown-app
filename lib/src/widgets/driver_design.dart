part of '../screens.dart';

/// Driver routes use the approved member typography and the original road artwork.
class RaDriverTheme extends StatelessWidget {
  const RaDriverTheme({super.key, required this.child});
  final Widget child;
  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<_DriverTypographyFlag>() != null;
  @override
  Widget build(BuildContext context) => RaProviderTheme(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            extensions: [
              ...theme.extensions.values.where(
                (e) => e is! _DriverTypographyFlag,
              ),
              const _DriverTypographyFlag(),
            ],
            scaffoldBackgroundColor: theme.brightness == Brightness.dark
                ? const Color(0xFF041426)
                : const Color(0xFFF7FBFF),
          ),
          child: child,
        );
      },
    ),
  );
}

class _DriverTypographyFlag extends ThemeExtension<_DriverTypographyFlag> {
  const _DriverTypographyFlag();
  @override
  _DriverTypographyFlag copyWith() => this;
  @override
  _DriverTypographyFlag lerp(
    covariant _DriverTypographyFlag? other,
    double t,
  ) => this;
}

class RaDriverScaffold extends RaScaffold {
  const RaDriverScaffold({
    super.key,
    super.appBar,
    super.body,
    super.backgroundColor,
    super.bottomNavigationBar,
    super.floatingActionButton,
    super.extendBodyBehindAppBar,
    super.extendBody,
    super.resizeToAvoidBottomInset,
    super.preventLeave,
    super.leaveMessage,
  });
  @override
  Widget build(BuildContext context) => RaDriverTheme(
    child: Builder(
      builder: (context) => RaScaffold(
        appBar: appBar,
        body: body,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        extendBody: extendBody,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        preventLeave: preventLeave,
        leaveMessage: leaveMessage,
      ),
    ),
  );
}

class RaDriverServiceTile extends StatelessWidget {
  const RaDriverServiceTile({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .10)
            : _providerSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: .45),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: colors.primary, size: 26),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: _providerText(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RaDriverAppBarTitle extends StatelessWidget {
  const RaDriverAppBarTitle(this.title, {super.key, this.style});
  final String title;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style ?? _providerText(context, size: 22, weight: FontWeight.w700),
  );
}
