part of '../../screens.dart';

class GpsIssueScreen
    extends StatefulWidget {
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

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaScaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Location Issue',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: ListView(
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          34,
        ),
        children: [
          const _RaGpsHero(),

          const SizedBox(height: 18),

          _RaGpsSignalPanel(
            retrying: retrying,
          ),

          const SizedBox(height: 27),

          Text(
            'Improve your location',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Try these steps before sending the roadside request.',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          const _RaGpsStep(
            number: '1',
            icon: Icons.gps_fixed_rounded,
            title:
                'Enable location services',
            message:
                'Make sure GPS and RoadAssist location permission are enabled.',
          ),

          const SizedBox(height: 9),

          const _RaGpsStep(
            number: '2',
            icon: Icons
                .open_in_full_rounded,
            title:
                'Move to an open area',
            message:
                'Buildings, covered parking and indoor spaces can reduce GPS accuracy.',
          ),

          const SizedBox(height: 9),

          const _RaGpsStep(
            number: '3',
            icon: Icons
                .edit_location_alt_outlined,
            title:
                'Adjust the point manually',
            message:
                'If GPS remains inaccurate, return and refine the pickup location manually.',
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed:
                retrying
                    ? null
                    : retryLocation,
            icon: retrying
                ? const SizedBox.square(
                    dimension: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons
                        .my_location_rounded,
                  ),
            label: Text(
              retrying
                  ? 'Checking Location…'
                  : 'Try Location Again',
            ),
          ),

          const SizedBox(height: 9),

          OutlinedButton.icon(
            onPressed: retrying
                ? null
                : () {
                    Navigator.pop(
                      context,
                    );
                  },
            icon: const Icon(
              Icons
                  .edit_location_alt_outlined,
            ),
            label: const Text(
              'Adjust Location Manually',
            ),
          ),

          const SizedBox(height: 9),

          TextButton.icon(
            onPressed: retrying
                ? null
                : () {
                    Geolocator
                        .openLocationSettings();
                  },
            icon: const Icon(
              Icons.settings_outlined,
            ),
            label: const Text(
              'Open Location Settings',
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding:
                const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.primary
                  .withValues(alpha: .055),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: colors.primary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Confirm the pickup point before sending your request. Accurate location information helps reduce provider delays.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 9.5,
                      height: 1.45,
                      color: colors
                          .onSurfaceVariant,
                    ),
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

class _RaGpsHero extends StatelessWidget {
  const _RaGpsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFFE7A126),
            Color(0xFFC57C0C),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -34,
            child: Icon(
              Icons.location_off_rounded,
              size: 125,
              color: Colors.white
                  .withValues(
                alpha: .08,
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .15,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Icon(
                  Icons
                      .location_off_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'Location needs attention',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: 290,
                child: Text(
                  'RoadAssist needs a reliable pickup point so the provider can find you safely.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .82,
                    ),
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaGpsSignalPanel
    extends StatelessWidget {
  const _RaGpsSignalPanel({
    required this.retrying,
  });

  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 155,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 145,
                  height: 145,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary
                        .withValues(
                      alpha: .025,
                    ),
                    border: Border.all(
                      color: colors.primary
                          .withValues(
                        alpha: .08,
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 103,
                  height: 103,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary
                        .withValues(
                      alpha: .035,
                    ),
                    border: Border.all(
                      color: colors.primary
                          .withValues(
                        alpha: .12,
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 65,
                  height: 65,
                  decoration:
                      BoxDecoration(
                    color: raGold
                        .withValues(
                      alpha: .12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    retrying
                        ? Icons
                            .gps_fixed_rounded
                        : Icons
                            .gps_not_fixed_rounded,
                    color: raGold,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            retrying
                ? 'Checking GPS signal…'
                : 'Location accuracy is low',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            retrying
                ? 'RoadAssist is checking whether your location can be used again.'
                : 'No pickup point will be assumed. Retry GPS or manually confirm your location before continuing.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              height: 1.45,
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          if (retrying) ...[
            const SizedBox(height: 13),

            const LinearProgressIndicator(
              minHeight: 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _RaGpsStep
    extends StatelessWidget {
  const _RaGpsStep({
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .43),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 41,
                height: 41,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 19,
                ),
              ),

              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    color: colors.primary,
                    shape:
                        BoxShape.circle,
                    border: Border.all(
                      color: colors.surface,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    number,
                    style: GoogleFonts
                        .plusJakartaSans(
                      color: colors
                          .onPrimary,
                      fontSize: 7,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.8,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.8,
                    height: 1.4,
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