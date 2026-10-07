part of '../../screens.dart';

class GpsIssueScreen extends StatefulWidget {
  const GpsIssueScreen({
    super.key,
  });

  @override
  State<GpsIssueScreen> createState() =>
      _GpsIssueScreenState();
}

class _GpsIssueScreenState
    extends State<GpsIssueScreen> {
  bool retrying = false;

  Future<void> retryLocation() async {
    if (retrying) return;

    setState(() {
      retrying = true;
    });

    await Future<void>.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    setState(() {
      retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Location Issue',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.md,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(
                RaSpace.lg,
              ),
              decoration: BoxDecoration(
                color: raGold.withValues(
                  alpha:
                      theme.brightness ==
                              Brightness.dark
                          ? .12
                          : .09,
                ),
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: raGold.withValues(
                    alpha: .30,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: raGold.withValues(
                        alpha: .15,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .location_off_outlined,
                      color: raGold,
                      size: 25,
                    ),
                  ),

                  const SizedBox(
                    width: RaSpace.md,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Location accuracy is low',
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          'RoadAssist needs an accurate pickup location so the selected provider can find you safely.',
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.lg,
            ),

            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius:
                    BorderRadius.circular(22),
                border: Border.all(
                  color: colors
                      .outlineVariant
                      .withValues(
                    alpha: .55,
                  ),
                ),
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  const SizedBox(
                    height: 310,
                    child: MapMock(),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.all(
                      RaSpace.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration:
                              BoxDecoration(
                            color: colors
                                .primaryContainer,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                          child: Icon(
                            Icons
                                .my_location_rounded,
                            size: 19,
                            color: colors
                                .onPrimaryContainer,
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
                                'Current location estimate',
                                style: theme
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                'Accuracy needs improvement before continuing.',
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: colors
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            Text(
              'Improve your location',
              style: theme
                  .textTheme.titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            const _GpsHelpStep(
              number: '1',
              icon:
                  Icons.gps_fixed_rounded,
              title:
                  'Keep location services enabled',
              message:
                  'Make sure location access is available while using RoadAssist.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            const _GpsHelpStep(
              number: '2',
              icon:
                  Icons.open_in_full_rounded,
              title:
                  'Move to an open area',
              message:
                  'Buildings, covered parking and indoor areas can reduce GPS accuracy.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            const _GpsHelpStep(
              number: '3',
              icon: Icons
                  .edit_location_alt_outlined,
              title:
                  'Adjust the point manually',
              message:
                  'If GPS remains inaccurate, return to the map and refine your pickup point.',
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            FilledButton.icon(
              onPressed:
                  retrying
                  ? null
                  : retryLocation,
              icon: retrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .my_location_rounded,
                    ),
              label: Text(
                retrying
                    ? 'Finding Location…'
                    : 'Try Location Again',
              ),
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            OutlinedButton.icon(
              onPressed:
                  retrying
                  ? null
                  : () =>
                      Navigator.pop(
                    context,
                  ),
              icon: const Icon(
                Icons
                    .edit_location_alt_outlined,
              ),
              label: const Text(
                'Adjust Location Manually',
              ),
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            Container(
              padding: const EdgeInsets.all(
                RaSpace.md,
              ),
              decoration: BoxDecoration(
                color: colors
                    .surfaceContainerHighest
                    .withValues(alpha: .32),
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .shield_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(
                    width: RaSpace.sm,
                  ),
                  Expanded(
                    child: Text(
                      'Confirm your pickup point before sending the request. Accurate location information helps reduce provider delays.',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsHelpStep extends StatelessWidget {
  const _GpsHelpStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.message,
  });

  final String number;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .5),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  colors.primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: colors
                      .onPrimaryContainer,
                ),
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment:
                        Alignment.center,
                    decoration:
                        const BoxDecoration(
                      color: raBlue,
                      shape:
                          BoxShape.circle,
                    ),
                    child: Text(
                      number,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 8,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ),
                ),
              ],
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
                  title,
                  style: theme
                      .textTheme.titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  message,
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
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