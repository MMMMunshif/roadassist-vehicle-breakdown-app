part of '../screens.dart';

Color _providerSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF0D2237)
    : Colors.white;

TextStyle _providerText(
  BuildContext context, {
  double size = 14,
  FontWeight weight = FontWeight.w500,
  bool muted = false,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  height: 1.4,
  fontWeight: weight,
  color: muted
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Theme.of(context).colorScheme.onSurface,
);

class RaProviderCard extends StatelessWidget {
  const RaProviderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _providerSurface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .45),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

/// Uses the existing brand asset and persistent theme controller.
class RaProviderHeader extends StatelessWidget {
  const RaProviderHeader({super.key, required this.notifications});
  final Widget notifications;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const BrandMark(size: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Road'),
                    TextSpan(
                      text: 'Assist',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                style: _providerText(
                  context,
                  size: 20,
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _WelcomeThemeToggle(),
        const SizedBox(width: 4),
        notifications,
      ],
    ),
  );
}

class RaProviderSection extends StatelessWidget {
  const RaProviderSection({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.caption,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? caption;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: _providerText(context, size: 17, weight: FontWeight.w800),
        ),
      ),
      if (caption != null)
        Flexible(
          child: Text(
            caption!,
            textAlign: TextAlign.right,
            style: _providerText(context, size: 12, muted: true),
          ),
        ),
      if (action != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class RaProviderEmptyCard extends StatelessWidget {
  const RaProviderEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _providerText(context, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: _providerText(context, size: 12, muted: true),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RaProviderIdentityCard extends StatelessWidget {
  const RaProviderIdentityCard({
    super.key,
    required this.avatar,
    required this.speciality,
    required this.online,
    required this.status,
    required this.onChanged,
    required this.onRefreshLocation,
    this.locationNeedsRefresh = false,
    this.locationMessage = '',
    this.busy = false,
  });
  final Widget avatar;
  final String speciality;
  final bool online;
  final String status;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRefreshLocation;
  final bool locationNeedsRefresh;
  final String locationMessage;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available =
        status == 'Online' || status == 'Busy' || locationNeedsRefresh;

    return RaProviderCard(
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  speciality,
                  style: _providerText(context, weight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: locationNeedsRefresh
                          ? colors.tertiary
                          : available
                          ? const Color(0xFF0CA98B)
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        status,
                        style: _providerText(context, size: 12, muted: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (online && locationNeedsRefresh) ...[
                  Text(
                    locationMessage,
                    style: _providerText(context, size: 12, muted: true),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : onRefreshLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Update location'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ] else
                  Text(
                    online
                        ? 'Matching requests depend on your services and availability.'
                        : 'Go online to receive nearby requests',
                    style: _providerText(context, size: 12, muted: true),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: 'Provider availability',
            child: Switch(value: online, onChanged: busy ? null : onChanged),
          ),
        ],
      ),
    );
  }
}

class RaProviderSettingRow extends StatelessWidget {
  const RaProviderSettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            return Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _providerText(context, size: 13)),
                      if (stacked && value != null)
                        Text(
                          value!,
                          style: _providerText(context, size: 12, muted: true),
                        ),
                    ],
                  ),
                ),
                if (!stacked && value != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        value!,
                        textAlign: TextAlign.right,
                        style: _providerText(context, size: 12, muted: true),
                      ),
                    ),
                  ),
                ?trailing,
                if (onTap != null && trailing == null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class RaProviderRequestTile extends StatelessWidget {
  const RaProviderRequestTile({
    super.key,
    required this.driver,
    required this.issue,
    required this.location,
    required this.time,
    required this.onView,
    this.distance,
    this.priority,
    this.onDismiss,
    this.offerSent = false,
    this.busy = false,
  });
  final String driver, issue, location, time;
  final String? distance, priority;
  final VoidCallback onView;
  final VoidCallback? onDismiss;
  final bool offerSent, busy;
  Widget _meta(BuildContext context, IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: _providerText(context, size: 13, muted: true),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ProfileInitials(name: driver, radius: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver,
                    style: _providerText(
                      context,
                      size: 15,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    issue,
                    style: _providerText(context, size: 13, muted: true),
                  ),
                ],
              ),
            ),
            if (priority != null)
              Flexible(
                child: StatusPill(label: priority!, tone: RaTone.warning),
              ),
            if (onDismiss != null)
              PopupMenuButton<String>(
                tooltip: 'Request options',
                enabled: !busy,
                onSelected: (_) => onDismiss!(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'dismiss',
                    child: Text('Dismiss request'),
                  ),
                ],
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Divider(height: 1),
        ),
        if (distance != null) _meta(context, Icons.near_me_outlined, distance!),
        _meta(context, Icons.location_on_outlined, location),
        _meta(context, Icons.schedule_outlined, time),
        if (offerSent)
          _meta(context, Icons.request_quote_outlined, 'Offer sent'),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy ? null : onView,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text('View request', textAlign: TextAlign.center),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Keeps the provider tab bar available when opening requests from dashboard/header.
class _ProviderNavigationScope extends InheritedWidget {
  const _ProviderNavigationScope({
    required this.onSelected,
    required super.child,
  });
  final ValueChanged<int> onSelected;
  @override
  bool updateShouldNotify(covariant _ProviderNavigationScope oldWidget) =>
      false;
}

void _openProviderRequests(BuildContext context) {
  final navigation = context
      .getInheritedWidgetOfExactType<_ProviderNavigationScope>();
  if (navigation != null) {
    navigation.onSelected(1);
  } else {
    push(context, const ProviderNotificationsScreen());
  }
}

void _openProviderProfile(BuildContext context) {
  final navigation = context
      .getInheritedWidgetOfExactType<_ProviderNavigationScope>();
  if (navigation != null) {
    navigation.onSelected(4);
  } else {
    push(context, const ProviderProfileScreen());
  }
}

/// Provider presentation is scoped; driver/admin routes retain their theme.
class RaProviderTheme extends StatelessWidget {
  const RaProviderTheme({super.key, required this.child});
  final Widget child;
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ProviderStyleScope>() != null ||
      Theme.of(context).extension<_ProviderTypographyFlag>() != null;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineSmall: _providerText(context, size: 22, weight: FontWeight.w700),
      titleLarge: _providerText(context, size: 22, weight: FontWeight.w700),
      titleMedium: _providerText(context, size: 16, weight: FontWeight.w600),
      titleSmall: _providerText(context, size: 15, weight: FontWeight.w600),
      bodyLarge: _providerText(context, size: 15),
      bodyMedium: _providerText(context, size: 14),
      bodySmall: _providerText(context, size: 12, muted: true),
      labelLarge: _providerText(context, size: 15, weight: FontWeight.w600),
      labelMedium: _providerText(context, size: 13),
      labelSmall: _providerText(context, size: 12),
    );
    final buttonText = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return _ProviderStyleScope(
      child: Theme(
        data: base.copyWith(
          extensions: [
            ...base.extensions.values.where(
              (extension) => extension is! _ProviderTypographyFlag,
            ),
            const _ProviderTypographyFlag(),
          ],
          textTheme: text,
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: text.titleLarge,
          ),
          cardTheme: base.cardTheme.copyWith(
            color: _providerSurface(context),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: base.colorScheme.outlineVariant.withValues(alpha: .45),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style:
                base.filledButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(buttonText),
                  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                ) ??
                FilledButton.styleFrom(
                  textStyle: buttonText,
                  minimumSize: const Size(48, 48),
                ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              textStyle: buttonText,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(textStyle: buttonText),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: _providerSurface(context),
            labelStyle: text.bodyMedium,
            hintStyle: text.bodyMedium?.copyWith(
              color: base.colorScheme.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ProviderStyleScope extends InheritedWidget {
  const _ProviderStyleScope({required super.child});
  @override
  bool updateShouldNotify(_ProviderStyleScope oldWidget) => false;
}

class RaProviderScaffold extends RaScaffold {
  const RaProviderScaffold({
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
  Widget build(BuildContext context) => RaProviderTheme(
    child: Builder(builder: (context) => super.build(context)),
  );
}

class RaProviderSummaryCard extends StatelessWidget {
  const RaProviderSummaryCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.status,
    this.footer,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? status;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            ?status,
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: _providerText(context, size: 18, weight: FontWeight.w700),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message, style: _providerText(context, size: 14, muted: true)),
        ],
        if (footer != null) ...[const SizedBox(height: 14), footer!],
      ],
    ),
  );
}

class RaProviderMetricGrid extends StatelessWidget {
  const RaProviderMetricGrid({super.key, required this.metrics});
  final Map<String, String> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 480 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 3
          : box.maxWidth >= 270 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in metrics.entries)
            SizedBox(
              width: (box.maxWidth - (columns - 1) * 10) / columns,
              child: RaProviderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.key,
                      style: _providerText(context, size: 12, muted: true),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: _providerText(
                        context,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class RaProviderJobProgress extends StatelessWidget {
  const RaProviderJobProgress({super.key, required this.current});
  final int current;
  @override
  Widget build(BuildContext context) {
    const labels = ['Accepted', 'En route', 'Arrived', 'Completed'];
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  i < current
                      ? Icons.check_circle
                      : i == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: i <= current
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    labels[i],
                    style: _providerText(
                      context,
                      size: 13,
                      weight: i == current ? FontWeight.w700 : FontWeight.w500,
                      muted: i > current,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

double providerFontSize(BuildContext context, double original) {
  if (!RaProviderTheme.isActive(context)) return original;
  if (original < 10) return 12;
  if (original < 12) return 13;
  if (original < 14) return 14;
  if (original < 16) return 15;
  if (original < 19) return 18;
  if (original < 25) return 22;
  return original;
}

class _ProviderTypographyFlag extends ThemeExtension<_ProviderTypographyFlag> {
  const _ProviderTypographyFlag();
  @override
  _ProviderTypographyFlag copyWith() => this;
  @override
  _ProviderTypographyFlag lerp(
    covariant _ProviderTypographyFlag? other,
    double t,
  ) => this;
}
