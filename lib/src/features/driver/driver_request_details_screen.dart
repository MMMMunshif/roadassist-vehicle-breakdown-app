part of '../../screens.dart';

class DriverRequestDetailsScreen
    extends StatelessWidget {
  const DriverRequestDetailsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Request Details',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              RaSpace.xl,
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                RaSpace.xl,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                border: Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .6,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
                        25,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .receipt_long_outlined,
                      color: colors
                          .onPrimaryContainer,
                      size: 36,
                    ),
                  ),

                  const SizedBox(
                    height: RaSpace.lg,
                  ),

                  Text(
                    'Choose a request',
                    textAlign:
                        TextAlign.center,
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: RaSpace.sm,
                  ),

                  Text(
                    'Open a request from your Requests history to view its live service details, provider information, invoice and rating options.',
                    textAlign:
                        TextAlign.center,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(
                    height: RaSpace.xl,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        FilledButton.icon(
                      onPressed: () =>
                          push(
                        context,
                        const HistoryScreen(),
                      ),
                      icon: const Icon(
                        Icons
                            .history_rounded,
                      ),
                      label:
                          const Text(
                        'Open My Requests',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: RaSpace.sm,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        OutlinedButton.icon(
                      onPressed: () =>
                          replace(
                        context,
                        const DriverShell(),
                      ),
                      icon: const Icon(
                        Icons
                            .home_outlined,
                      ),
                      label:
                          const Text(
                        'Back to Home',
                      ),
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