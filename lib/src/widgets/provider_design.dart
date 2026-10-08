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
    this.busy = false,
  });
  final Widget avatar;
  final String speciality;
  final bool online;
  final String status;
  final ValueChanged<bool> onChanged;
  final bool busy;
  @override
  Widget build(BuildContext context) => RaProviderCard(
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
                    color: online
                        ? const Color(0xFF0CA98B)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
