part of '../../screens.dart';

class DriverRequestDetailsScreen
    extends StatelessWidget {
  const DriverRequestDetailsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dark =
        theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Request Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              24,
              20,
              32,
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      23,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(
                              0xFF0D1D2B,
                            )
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        26,
                      ),
                      border: Border.all(
                        color: colors
                            .outlineVariant
                            .withValues(
                          alpha: .48,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration:
                              BoxDecoration(
                            gradient:
                                LinearGradient(
                              begin: Alignment
                                  .topLeft,
                              end: Alignment
                                  .bottomRight,
                              colors: [
                                colors.primary
                                    .withValues(
                                  alpha: .18,
                                ),
                                const Color(
                                  0xFF078F80,
                                ).withValues(
                                  alpha: .12,
                                ),
                              ],
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              23,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .receipt_long_rounded,
                            color:
                                colors.primary,
                            size: 32,
                          ),
                        ),

                        const SizedBox(height: 19),

                        Text(
                          'Choose a request',
                          textAlign:
                              TextAlign.center,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: -.6,
                            color:
                                colors.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Open one of your assistance requests to see live status, provider details, agreed pricing, invoices and service options.',
                          textAlign:
                              TextAlign.center,
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 11,
                            height: 1.55,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 22),

                        const _DriverRequestEntryFeature(
                          icon: Icons
                              .near_me_outlined,
                          title:
                              'Live service tracking',
                          description:
                              'Follow accepted, en-route and arrived jobs.',
                        ),

                        const SizedBox(height: 9),

                        const _DriverRequestEntryFeature(
                          icon: Icons
                              .payments_outlined,
                          title:
                              'Quotes & invoices',
                          description:
                              'Review approved service prices and receipts.',
                        ),

                        const SizedBox(height: 9),

                        const _DriverRequestEntryFeature(
                          icon: Icons
                              .history_rounded,
                          title:
                              'Service history',
                          description:
                              'Access completed and cancelled requests.',
                        ),

                        const SizedBox(height: 23),

                        SizedBox(
                          width: double.infinity,
                          child:
                              FilledButton.icon(
                            onPressed: () {
                              push(
                                context,
                                const HistoryScreen(),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .receipt_long_rounded,
                            ),
                            label: const Text(
                              'Open My Requests',
                            ),
                          ),
                        ),

                        const SizedBox(height: 9),

                        SizedBox(
                          width: double.infinity,
                          child:
                              OutlinedButton.icon(
                            onPressed: () {
                              push(
                                context,
                                const AssistanceTypeScreen(),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .add_road_rounded,
                            ),
                            label: const Text(
                              'Start New Assistance',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextButton.icon(
                    onPressed: () {
                      replace(
                        context,
                        const DriverShell(),
                      );
                    },
                    icon: const Icon(
                      Icons.home_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Return to Home',
                    ),
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

class _DriverRequestEntryFeature
    extends StatelessWidget {
  const _DriverRequestEntryFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .32),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .09),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colors.primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 9.5,
                    height: 1.35,
                    color: colors
                        .onSurfaceVariant,
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