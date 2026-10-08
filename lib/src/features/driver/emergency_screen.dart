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
      showDragHandle: true,
      builder: (
        sheetContext,
      ) {
        final colors =
            Theme.of(sheetContext)
                .colorScheme;

        return Padding(
          padding:
              EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.of(
                      sheetContext,
                    ).viewInsets.bottom +
                18,
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
                Row(
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration:
                          BoxDecoration(
                        color: colors.error
                            .withValues(
                          alpha: .08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .contact_emergency_outlined,
                        color:
                            colors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            'Save a trusted contact for roadside situations.',
                            style: GoogleFonts
                                .plusJakartaSans(
                              fontSize: 8,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                        '+94 77 123 4567',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                  ),
                  validator:
                      validateSriLankaPhone,
                  onChanged: (
                    value,
                  ) {
                    updatedContact =
                        value;
                  },
                  onFieldSubmitted: (_) {
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
                const SizedBox(height: 16),
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

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency contact saved.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save emergency contact: $error',
          ),
          backgroundColor:
              raDanger,
        ),
      );
    }
  }

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
          'Emergency',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: !signedIn
          ? const Padding(
              padding:
                  EdgeInsets.all(18),
              child: EmptyState(
                icon:
                    Icons.login_outlined,
                title:
                    'Sign in required',
                message:
                    'Sign in as a driver to manage an emergency contact.',
              ),
            )
          : StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
              stream: AuthService()
                  .watchCurrentProfile(),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding:
                        EdgeInsets.all(
                      18,
                    ),
                    child: EmptyState(
                      icon: Icons
                          .cloud_off_outlined,
                      title:
                          'Unable to load emergency information',
                      message:
                          'Check your connection and try again.',
                    ),
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
                        <String, dynamic>{};

                final contact =
                    data['emergencyContact']
                            ?.toString() ??
                        '';

                final configured =
                    contact.trim().isNotEmpty &&
                        contact !=
                            'Not added';

                final location =
                    data['currentLocationLabel']
                            ?.toString()
                            .trim() ??
                        '';

                final hasLocation =
                    location.isNotEmpty;

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
                    const SizedBox(height: 23),
                    const _RaEmergencyHeading(
                      title:
                          'Emergency services',
                      subtitle:
                          'Use emergency services immediately if there is danger to life or safety.',
                    ),
                    const SizedBox(height: 10),
                    _RaEmergencyActionCard(
                      icon:
                          Icons.sos_rounded,
                      title:
                          'Police Emergency',
                      subtitle:
                          'Call 119 for immediate emergency assistance.',
                      label:
                          'Call 119',
                      danger: true,
                      onTap: () {
                        showCallPrompt(
                          context,
                          name:
                              'Emergency Services',
                          number: '119',
                        );
                      },
                    ),
                    const SizedBox(height: 23),
                    const _RaEmergencyHeading(
                      title:
                          'Trusted contact',
                      subtitle:
                          'A personal contact you may need during roadside assistance.',
                    ),
                    const SizedBox(height: 10),
                    _RaEmergencySurface(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration:
                                    BoxDecoration(
                                  color: colors
                                      .primary
                                      .withValues(
                                    alpha: .08,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    14,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .contact_emergency_outlined,
                                  color: colors
                                      .primary,
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
                                      'Family Contact',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            10.5,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Text(
                                      configured
                                          ? contact
                                          : 'No emergency contact added',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            8,
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    configured
                                        ? 'Change contact'
                                        : 'Add contact',
                                onPressed: () {
                                  editContact(
                                    context,
                                    contact,
                                  );
                                },
                                icon: const Icon(
                                  Icons
                                      .edit_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          FilledButton.icon(
                            onPressed: configured
                                ? () {
                                    showCallPrompt(
                                      context,
                                      name:
                                          'Family Contact',
                                      number:
                                          contact,
                                    );
                                  }
                                : () {
                                    editContact(
                                      context,
                                      contact,
                                    );
                                  },
                            icon: Icon(
                              configured
                                  ? Icons
                                      .call_rounded
                                  : Icons
                                      .person_add_alt_1_outlined,
                            ),
                            label: Text(
                              configured
                                  ? 'Call Emergency Contact'
                                  : 'Add Emergency Contact',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 23),
                    const _RaEmergencyHeading(
                      title:
                          'Current location',
                      subtitle:
                          'Share the saved RoadAssist location when it is useful and accurate.',
                    ),
                    const SizedBox(height: 10),
                    _RaEmergencySurface(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Container(
                                width: 43,
                                height: 43,
                                decoration:
                                    BoxDecoration(
                                  color: hasLocation
                                      ? colors
                                          .primary
                                          .withValues(
                                          alpha:
                                              .08,
                                        )
                                      : colors
                                          .surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    13,
                                  ),
                                ),
                                child: Icon(
                                  hasLocation
                                      ? Icons
                                          .location_on_rounded
                                      : Icons
                                          .location_off_outlined,
                                  color: hasLocation
                                      ? colors
                                          .primary
                                      : colors
                                          .onSurfaceVariant,
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
                                      hasLocation
                                          ? location
                                          : 'Current location not available',
                                      style: GoogleFonts
                                          .plusJakartaSans(
                                        fontSize:
                                            9.2,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        height:
                                            1.4,
                                      ),
                                    ),
                                    if (!hasLocation) ...[
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        'RoadAssist has no saved location to share from your profile.',
                                        style: GoogleFonts
                                            .plusJakartaSans(
                                          fontSize:
                                              7.6,
                                          color: colors
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          OutlinedButton.icon(
                            onPressed: hasLocation
                                ? () {
                                    copyLocation(
                                      context,
                                      location,
                                    );
                                  }
                                : null,
                            icon: const Icon(
                              Icons
                                  .content_copy_outlined,
                            ),
                            label: const Text(
                              'Copy Location',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration: BoxDecoration(
                        color: raGold
                            .withValues(
                          alpha: .07,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
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
                            size: 19,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              'Do not stay in moving traffic just to use the app. Move to a safer location when possible and contact emergency services first when there is immediate danger.',
                              style: GoogleFonts
                                  .plusJakartaSans(
                                fontSize: 8,
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
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFFD8362A),
            Color(0xFFA92720),
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -28,
            child: Icon(
              Icons.sos_rounded,
              size: 120,
              color: Colors.white
                  .withValues(alpha: .07),
            ),
          ),
          Row(
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
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Emergency assistance',
                      style: GoogleFonts
                          .plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For immediate danger, contact emergency services before continuing with RoadAssist.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        color:
                            Colors.white70,
                        fontSize: 8.4,
                        height: 1.4,
                      ),
                    ),
                  ],
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
            fontSize: 14.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaEmergencySurface
    extends StatelessWidget {
  const _RaEmergencySurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _RaEmergencyActionCard
    extends StatelessWidget {
  const _RaEmergencyActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final tone =
        danger
            ? colors.error
            : colors.primary;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .06),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              tone.withValues(alpha: .20),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: tone.withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: tone,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 7.8,
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
          FilledButton.icon(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor:
                        colors.error,
                    foregroundColor:
                        colors.onError,
                  )
                : null,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}