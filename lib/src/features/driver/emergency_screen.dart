part of '../../screens.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({
    super.key,
  });

  Future<void> editContact(
    BuildContext context,
    String currentContact,
  ) async {
    final formKey =
        GlobalKey<FormState>();

    var updatedContact =
        currentContact == 'Not added'
            ? ''
            : currentContact;

    final value =
        await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              sheetContext,
            ).viewInsets.bottom,
          ),
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              24,
            ),
            decoration: BoxDecoration(
              color: dark
                  ? const Color(
                      0xFF0D1D2B,
                    )
                  : colors.surface,
              borderRadius:
                  const BorderRadius
                      .vertical(
                top:
                    Radius.circular(28),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .onSurfaceVariant
                            .withValues(
                          alpha: .24,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 21,
                  ),

                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color: raDanger
                              .withValues(
                            alpha: .10,
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
                              .contact_emergency_outlined,
                          color:
                              raDanger,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Emergency contact',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color: colors
                                    .onSurface,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              'Add a trusted person you can call during roadside emergencies.',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 9.5,
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

                  const SizedBox(
                    height: 20,
                  ),

                  TextFormField(
                    initialValue:
                        updatedContact,
                    autofocus: true,
                    keyboardType:
                        TextInputType.phone,
                    textInputAction:
                        TextInputAction.done,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Phone number',
                      hintText:
                          '077 123 4567',
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                      ),
                    ),
                    validator:
                        validateSriLankaPhone,
                    onChanged: (value) {
                      updatedContact =
                          value;
                    },
                    onFieldSubmitted:
                        (_) {
                      if (formKey
                              .currentState
                              ?.validate() ??
                          false) {
                        Navigator.pop(
                          sheetContext,
                          normalizeSriLankaPhone(
                            updatedContact,
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  FilledButton.icon(
                    onPressed: () {
                      if (!(formKey
                              .currentState
                              ?.validate() ??
                          false)) {
                        return;
                      }

                      Navigator.pop(
                        sheetContext,
                        normalizeSriLankaPhone(
                          updatedContact,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                    label: const Text(
                      'Save Contact',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (value == null ||
        value.isEmpty ||
        !context.mounted) {
      return;
    }

    try {
      await AuthService()
          .updateCurrentProfile({
        'emergencyContact': value,
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency contact saved.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save emergency contact: $error',
          ),
          backgroundColor: raDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Emergency',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
      ),
      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message:
                    'Sign in as a driver to manage an emergency contact.',
              ),
            )
          : StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
              stream: AuthService()
                  .watchCurrentProfile(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon:
                        Icons.cloud_off_outlined,
                    title:
                        'Unable to load emergency details',
                    message:
                        'Check your connection and try again.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final data =
                    snapshot.data!.data() ??
                        {};

                final contact =
                    data['emergencyContact']
                            as String? ??
                        '';

                final configured =
                    contact.trim().isNotEmpty &&
                        contact !=
                            'Not added';

                final location =
                    data['currentLocationLabel']
                            as String? ??
                        'Current location not available';

                final hasLocation =
                    location !=
                        'Current location not available';

                return ListView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    32,
                  ),
                  children: [
                    const _RaEmergencyHero(),

                    const SizedBox(
                      height: 26,
                    ),

                    const _RaEmergencyHeading(
                      title:
                          'Emergency services',
                      subtitle:
                          'Use official emergency contacts when there is immediate danger.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaEmergencyAction(
                      icon:
                          Icons.local_police_outlined,
                      title:
                          'Police Emergency',
                      number: '119',
                      message:
                          'For urgent police or public safety assistance.',
                      tone: raDanger,
                      onTap: () {
                        showCallPrompt(
                          context,
                          name:
                              'Police Emergency',
                          number: '119',
                        );
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _RaEmergencyAction(
                      icon:
                          Icons.emergency_outlined,
                      title:
                          'Suwa Seriya Ambulance',
                      number: '1990',
                      message:
                          'Emergency ambulance service.',
                      tone:
                          const Color(
                        0xFFD8362A,
                      ),
                      onTap: () {
                        showCallPrompt(
                          context,
                          name:
                              'Suwa Seriya Ambulance',
                          number: '1990',
                        );
                      },
                    ),

                    const SizedBox(
                      height: 27,
                    ),

                    const _RaEmergencyHeading(
                      title:
                          'Trusted contact',
                      subtitle:
                          'Keep a personal contact ready for roadside situations.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaEmergencyContactCard(
                      contact: contact,
                      configured:
                          configured,
                      onEdit: () {
                        editContact(
                          context,
                          contact,
                        );
                      },
                      onCall: configured
                          ? () {
                              showCallPrompt(
                                context,
                                name:
                                    'Emergency Contact',
                                number:
                                    contact,
                              );
                            }
                          : null,
                    ),

                    const SizedBox(
                      height: 27,
                    ),

                    const _RaEmergencyHeading(
                      title:
                          'Current location',
                      subtitle:
                          'Share the saved location if someone needs to find you.',
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    _RaEmergencyLocationCard(
                      location: location,
                      available:
                          hasLocation,
                      onCopy: hasLocation
                          ? () {
                              copyLocation(
                                context,
                                location,
                              );
                            }
                          : null,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color: raGold
                            .withValues(
                          alpha: .09,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          17,
                        ),
                        border: Border.all(
                          color: raGold
                              .withValues(
                            alpha: .20,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons
                                .warning_amber_rounded,
                            color: raGold,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 9,
                          ),
                          Expanded(
                            child: Text(
                              'If you are in immediate danger, move to a safe place if possible and contact emergency services before continuing with RoadAssist.',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 10,
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
                );
              },
            ),
    );
  }
}

class _RaEmergencyHero
    extends StatelessWidget {
  const _RaEmergencyHero();

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
            Color(0xFFD8362A),
            Color(0xFF9D2721),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -32,
            child: Icon(
              Icons.sos_rounded,
              size: 125,
              color: Colors.white
                  .withValues(alpha: .07),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 51,
                height: 51,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Icon(
                  Icons
                      .health_and_safety_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'Emergency assistance',
                style: GoogleFonts
                    .plusJakartaSans(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.55,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: 290,
                child: Text(
                  'Quick access to official emergency services, your trusted contact and saved location.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .82,
                    ),
                    fontSize: 10.5,
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

class _RaEmergencyHeading
    extends StatelessWidget {
  const _RaEmergencyHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 10,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaEmergencyAction
    extends StatelessWidget {
  const _RaEmergencyAction({
    required this.icon,
    required this.title,
    required this.number,
    required this.message,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String number;
  final String message;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .065),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              tone.withValues(alpha: .18),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: tone
                      .withValues(alpha: .11),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 22,
                ),
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
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                number,
                style:
                    GoogleFonts.plusJakartaSans(
                  color: tone,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(
                backgroundColor: tone,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: onTap,
              icon:
                  const Icon(Icons.call_rounded),
              label: Text(
                'Call $number',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaEmergencyContactCard
    extends StatelessWidget {
  const _RaEmergencyContactCard({
    required this.contact,
    required this.configured,
    required this.onEdit,
    required this.onCall,
  });

  final String contact;
  final bool configured;
  final VoidCallback onEdit;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  Icons
                      .contact_emergency_outlined,
                  color: colors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Contact',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      configured
                          ? contact
                          : 'No trusted contact added',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: configured
                    ? 'Change contact'
                    : 'Add contact',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed:
                  configured
                      ? onCall
                      : onEdit,
              icon: Icon(
                configured
                    ? Icons.call_rounded
                    : Icons
                        .person_add_alt_1_outlined,
              ),
              label: Text(
                configured
                    ? 'Call Emergency Contact'
                    : 'Add Emergency Contact',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaEmergencyLocationCard
    extends StatelessWidget {
  const _RaEmergencyLocationCard({
    required this.location,
    required this.available,
    required this.onCopy,
  });

  final String location;
  final bool available;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: available
                      ? colors.primary
                          .withValues(
                          alpha: .08,
                        )
                      : colors
                          .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  available
                      ? Icons
                          .location_on_rounded
                      : Icons
                          .location_off_outlined,
                  color: available
                      ? colors.primary
                      : colors
                          .onSurfaceVariant,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  location,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    height: 1.45,
                    fontWeight:
                        FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(
                Icons
                    .share_location_outlined,
              ),
              label: const Text(
                'Copy / Share Location',
              ),
            ),
          ),
        ],
      ),
    );
  }
}