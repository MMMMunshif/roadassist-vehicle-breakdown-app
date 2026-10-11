part of '../../screens.dart';

class DriverRequestDetailsScreen extends StatelessWidget {
  const DriverRequestDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: RaDriverAppBarTitle(
          'Request Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF0D2237) : colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .45),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.primary.withValues(alpha: .16),
                                const Color(0xFF078F80).withValues(alpha: .10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: colors.primary,
                            size: 31,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Choose a request',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          'Open one of your assistance requests to view live status, provider details, pricing, invoices and service options.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const _RaRequestEntryFeature(
                          icon: Icons.near_me_outlined,
                          title: 'Live service tracking',
                          description:
                              'Follow accepted, en-route and arrived jobs.',
                        ),

                        const SizedBox(height: 8),

                        const _RaRequestEntryFeature(
                          icon: Icons.payments_outlined,
                          title: 'Quotes & invoices',
                          description:
                              'Review recorded service prices and receipts.',
                        ),

                        const SizedBox(height: 8),

                        const _RaRequestEntryFeature(
                          icon: Icons.history_rounded,
                          title: 'Service history',
                          description:
                              'Access completed and cancelled requests.',
                        ),

                        const SizedBox(height: 21),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              push(context, const HistoryScreen());
                            },
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('Open My Requests'),
                          ),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              push(context, const AssistanceTypeScreen());
                            },
                            icon: const Icon(Icons.add_road_rounded),
                            label: const Text('Start New Assistance'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextButton.icon(
                    onPressed: () {
                      replace(context, const DriverShell());
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RaRequestEntryFeature extends StatelessWidget {
  const _RaRequestEntryFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.onSurfaceVariant,
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
