part of '../../screens.dart';

class ProviderCompletedScreen
    extends StatelessWidget {
  const ProviderCompletedScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  final String requestId;

  final Map<String, dynamic>
      requestData;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final vehicle = [
      requestData['modelYear'],
      requestData[
          'registration'],
    ]
        .whereType<String>()
        .where(
          (value) =>
              value
                  .trim()
                  .isNotEmpty,
        )
        .join(' • ');

    return Scaffold(
      backgroundColor:
          theme
              .scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Job Completed',
        ),
        actions: [
          IconButton(
            tooltip: 'Invoice',
            icon: const Icon(
              Icons
                  .receipt_long_outlined,
            ),
            onPressed: () => push(
              context,
              InvoiceScreen(
                requestId:
                    requestId,
              ),
            ),
          ),
          const SizedBox(
            width: RaSpace.sm,
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets
                  .fromLTRB(
            RaSpace.lg,
            RaSpace.xl,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration:
                    BoxDecoration(
                  color:
                      raSuccessPale,
                  borderRadius:
                      BorderRadius
                          .circular(
                    30,
                  ),
                ),
                child: const Icon(
                  Icons
                      .task_alt_rounded,
                  size: 48,
                  color:
                      raSuccess,
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            Text(
              'Assistance completed',
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            Text(
              'Request $requestId has been completed. Review the final service summary below.',
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
              height: RaSpace.xxl,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .all(
                RaSpace.lg,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.surface,
                borderRadius:
                    BorderRadius
                        .circular(
                  20,
                ),
                border:
                    Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .6,
                  ),
                ),
              ),
              child: Column(
                children: [
                  _ProviderCompletedRow(
                    icon: Icons
                        .car_repair_outlined,
                    label:
                        'Service',
                    value:
                        requestIssueLabel(
                      requestData,
                    ),
                  ),
                  _ProviderCompletedRow(
                    icon: Icons
                        .person_outline_rounded,
                    label:
                        'Driver',
                    value:
                        requestData[
                                'driverName']
                            as String? ??
                            'Driver',
                  ),
                  _ProviderCompletedRow(
                    icon: Icons
                        .directions_car_outlined,
                    label:
                        'Vehicle',
                    value:
                        vehicle.isEmpty
                            ? 'Not provided'
                            : vehicle,
                  ),
                  _ProviderCompletedRow(
                    icon: Icons
                        .location_on_outlined,
                    label:
                        'Location',
                    value:
                        requestData[
                                'locationLabel']
                            as String? ??
                            'Pinned location',
                  ),
                  if ((requestData[
                                  'serviceNotes']
                              as String? ??
                          '')
                      .trim()
                      .isNotEmpty)
                    _ProviderCompletedRow(
                      icon: Icons
                          .notes_outlined,
                      label:
                          'Service notes',
                      value:
                          requestData[
                                  'serviceNotes']
                              as String,
                    ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .all(
                RaSpace.lg,
              ),
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin: Alignment
                      .topLeft,
                  end: Alignment
                      .bottomRight,
                  colors: [
                    colors.primary,
                    const Color(
                      0xFF007D70,
                    ),
                  ],
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  20,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .white
                          .withValues(
                        alpha: .14,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .payments_outlined,
                      color:
                          Colors.white,
                    ),
                  ),
                  const SizedBox(
                    width:
                        RaSpace.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Final service total',
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  .78,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Rs. ${requestData['finalCost'] ?? requestData['estimatedCost'] ?? 0}',
                          style: theme
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.xxl,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: () =>
                    push(
                  context,
                  InvoiceScreen(
                    requestId:
                        requestId,
                  ),
                ),
                icon: const Icon(
                  Icons
                      .receipt_long_outlined,
                ),
                label: const Text(
                  'View Invoice',
                ),
              ),
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  FilledButton.icon(
                onPressed: () =>
                    replace(
                  context,
                  const ProviderShell(),
                ),
                icon: const Icon(
                  Icons
                      .dashboard_outlined,
                ),
                label: const Text(
                  'Back to Dashboard',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCompletedRow
    extends StatelessWidget {
  const _ProviderCompletedRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: RaSpace.sm,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color:
                  colors.primary,
            ),
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                    height: 1.4,
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