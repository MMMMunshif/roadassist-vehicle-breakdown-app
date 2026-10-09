part of '../screens.dart';

/// Admin routes use the approved member typography and the original road artwork.
class RaAdminTheme extends StatelessWidget {
  const RaAdminTheme({super.key, required this.child});
  final Widget child;
  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<_AdminTypographyFlag>() != null;
  @override
  Widget build(BuildContext context) => RaProviderTheme(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            extensions: [
              ...theme.extensions.values.where(
                (e) => e is! _AdminTypographyFlag,
              ),
              const _AdminTypographyFlag(),
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

class _AdminTypographyFlag extends ThemeExtension<_AdminTypographyFlag> {
  const _AdminTypographyFlag();
  @override
  _AdminTypographyFlag copyWith() => this;
  @override
  _AdminTypographyFlag lerp(covariant _AdminTypographyFlag? other, double t) =>
      this;
}

class RaAdminScaffold extends RaScaffold {
  const RaAdminScaffold({
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
  Widget build(BuildContext context) => RaAdminTheme(
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

/// Keeps every authorized workspace reachable on a phone.
class AdminNavigationBar extends StatelessWidget {
  const AdminNavigationBar({
    super.key,
    required this.selected,
    required this.destinations,
    required this.onSelected,
  });
  final int selected;
  final List<({int index, String label, IconData icon})> destinations;
  final ValueChanged<int> onSelected;
  Future<void> _more(BuildContext context) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Admin workspaces',
                  style: _providerText(
                    context,
                    size: 22,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in destinations)
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        selected: selected == item.index,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, item.index),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) onSelected(choice);
  }

  @override
  Widget build(BuildContext context) {
    final primary = destinations
        .where((d) => const [0, 1, 2, 8].contains(d.index))
        .toList();
    final colors = Theme.of(context).colorScheme;
    final isMore = !primary.any((d) => d.index == selected);
    Widget item(
      IconData icon,
      String label,
      bool active,
      VoidCallback action,
    ) => Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary.withValues(alpha: .10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      _providerText(
                        context,
                        size: 12,
                        weight: active ? FontWeight.w700 : FontWeight.w500,
                      ).copyWith(
                        color: active
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Material(
      color: _providerSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in primary)
              item(
                d.icon,
                d.label,
                selected == d.index,
                () => onSelected(d.index),
              ),
            item(Icons.grid_view_rounded, 'More', isMore, () => _more(context)),
          ],
        ),
      ),
    );
  }
}
