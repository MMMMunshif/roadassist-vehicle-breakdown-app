part of '../../screens.dart';

class RoleSelectionScreen
    extends StatelessWidget {
  const RoleSelectionScreen({
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
        title: Text(
          'Choose Account Type',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            6,
            18,
            30,
          ),
          children: [
            const _AuthWordmark(),

            const SizedBox(height: 21),

            const _RoleSelectionHero(),

            const SizedBox(height: 22),

            _AuthRoleCard(
              icon: Icons
                  .directions_car_filled_outlined,
              title: 'Driver',
              eyebrow:
                  'NEED ROADSIDE HELP',
              description:
                  'Request roadside assistance, manage your vehicles and follow your active service.',
              highlights: const [
                'Save and manage vehicles',
                'Compare provider offers',
                'Track roadside assistance',
              ],
              buttonLabel:
                  'Continue as Driver',
              tone:
                  colors.primary,
              onTap: () {
                push(
                  context,
                  const LoginScreen(
                    isProvider: false,
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _AuthRoleCard(
              icon: Icons
                  .home_repair_service_outlined,
              title: 'Service Provider',
              eyebrow:
                  'PROFESSIONAL PORTAL',
              description:
                  'Receive matching roadside requests, submit quotes and manage active service jobs.',
              highlights: const [
                'Provider verification',
                'Manage matching requests',
                'Track active jobs',
              ],
              buttonLabel:
                  'Continue as Provider',
              tone:
                  const Color(0xFF078F80),
              onTap: () {
                push(
                  context,
                  const LoginScreen(
                    isProvider: true,
                  ),
                );
              },
            ),

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: Divider(
                    color:
                        colors.outlineVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'EMERGENCY ACCESS',
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: .8,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    color:
                        colors.outlineVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.error
                    .withValues(alpha: .055),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: colors.error
                      .withValues(alpha: .17),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration:
                            BoxDecoration(
                          color: colors.error
                              .withValues(
                            alpha: .09,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .emergency_outlined,
                          color:
                              colors.error,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Need urgent access?',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              'Continue to limited driver emergency access without signing in.',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 11,
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

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            colors.error,
                        side: BorderSide(
                          color: colors.error
                              .withValues(
                            alpha: .35,
                          ),
                        ),
                      ),
                      onPressed: () {
                        replace(
                          context,
                          const DriverShell(),
                        );
                      },
                      icon: const Icon(
                        Icons
                            .emergency_outlined,
                      ),
                      label: const Text(
                        'Emergency Guest Access',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Choose the account type that matches how you use RoadAssist.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelectionHero
    extends StatelessWidget {
  const _RoleSelectionHero();

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF07508B),
                  Color(0xFF076864),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078F80),
                ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons
                  .account_circle_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'How will you use RoadAssist?',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Select a driver or provider account to continue.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .78,
                    ),
                    fontSize: 11.5,
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

class _AuthRoleCard
    extends StatelessWidget {
  const _AuthRoleCard({
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.highlights,
    required this.buttonLabel,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String eyebrow;
  final String description;
  final List<String> highlights;
  final String buttonLabel;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : colors.surface,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .50),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  color: tone.withValues(
                    alpha: .09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 25,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        letterSpacing: .65,
                        fontWeight:
                            FontWeight.w700,
                        color: tone,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            description,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.5,
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 13),

          for (final item
              in highlights)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 7,
              ),
              child: Row(
                children: [
                  Container(
                    width: 23,
                    height: 23,
                    decoration:
                        BoxDecoration(
                      color: raSuccess
                          .withValues(
                        alpha: .09,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        7,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: raSuccess,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 9),

          SizedBox(
            height: 49,
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(
                backgroundColor: tone,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: onTap,
              icon: const Icon(
                Icons
                    .arrow_forward_rounded,
              ),
              label:
                  Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}