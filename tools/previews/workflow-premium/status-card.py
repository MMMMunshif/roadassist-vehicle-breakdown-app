from pathlib import Path
p=Path('lib/src/features/request/tracking_screen.dart');s=p.read_text(encoding='utf-8');s+='''
/// Presentation follows server state; GPS refreshes never restart stage motion.
class ActiveAssistanceStatusCard extends StatelessWidget {
  const ActiveAssistanceStatusCard({
    super.key,
    required this.status,
    required this.title,
    required this.description,
    this.cancelled = false,
    this.completionPending = false,
  });
  final int status;
  final String title;
  final String description;
  final bool cancelled;
  final bool completionPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = cancelled ? colors.error : status >= 3 ? raSuccess : colors.primary;
    final reduced = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final duration = reduced ? Duration.zero : const Duration(milliseconds: 420);
    final icon = cancelled ? Icons.close_rounded : completionPending
        ? Icons.receipt_long_outlined : switch (status) {
          0 => Icons.handshake_outlined,
          1 => Icons.navigation_outlined,
          2 => Icons.car_repair_outlined,
          _ => Icons.task_alt_rounded,
        };
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: .18), tone.withValues(alpha: .04)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tone.withValues(alpha: .25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tone.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tone, size: 23)),
          const SizedBox(width: 12),
          Expanded(child: Text(cancelled ? 'REQUEST CLOSED' : status >= 3
              ? 'SERVICE COMPLETED' : 'ACTIVE ASSISTANCE',
            style: roadAssistTextStyle(fontSize: 10, letterSpacing: 1.5,
              fontWeight: FontWeight.w800, color: tone))),
        ]),
        const SizedBox(height: 20),
        Semantics(liveRegion: true, child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .08),
              end: Offset.zero).animate(animation), child: child)),
          child: Align(key: ValueKey('$status/$cancelled/$completionPending/$title'),
            alignment: Alignment.centerLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: roadAssistTextStyle(fontSize: 24, height: 1.2,
                letterSpacing: -.7, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(description, style: roadAssistTextStyle(fontSize: 13, height: 1.5,
                color: colors.onSurfaceVariant)),
            ])),
        )),
        if (!cancelled) ...[
          const SizedBox(height: 24),
          StatusTimeline(statuses: const ['Accepted', 'En route', 'Arrived', 'Completed'],
            current: status.clamp(0, 3)),
        ],
      ]),
    );
  }
}
''';p.write_text(s,encoding='utf-8')
