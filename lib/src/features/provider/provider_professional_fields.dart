part of '../../screens.dart';

class _ProviderProfessionalFields extends StatelessWidget {
  const _ProviderProfessionalFields({
    required this.controllers,
    required this.details,
    required this.onChanged,
    required this.towing,
    required this.busy,
  });

  final Map<String, TextEditingController> controllers;
  final Map<String, dynamic> details;
  final VoidCallback onChanged;
  final bool towing;
  final bool busy;

  static const textFields = {
    'businessPhone': (
      'Service contact phone',
      16,
    ),
    'businessRegistration': (
      'Business registration number',
      60,
    ),
    'workHistory': (
      'Brief work experience (optional)',
      1000,
    ),
    'qualification': (
      'Qualification or practical training completed',
      150,
    ),
    'trainingInstitute': (
      'Training institute / on-the-job training workplace',
      150,
    ),
    'qualificationYear': (
      'Training completion year (0 if ongoing)',
      4,
    ),
    'specializations': (
      'Specializations, vehicle makes and systems you repair',
      300,
    ),
    'coverageAreas': (
      'Towns / districts you cover',
      300,
    ),
    'radiusKm': (
      'Maximum service radius (km)',
      3,
    ),
    'startTime': (
      'Start time (24-hour HH:mm)',
      5,
    ),
    'endTime': (
      'End time (24-hour HH:mm; may end next day)',
      5,
    ),
    'towRegistration': (
      'Recovery vehicle registration',
      20,
    ),
    'towCapacityKg': (
      'Maximum safe recovery capacity (kg)',
      5,
    ),
    'insuranceDetails': (
      'Insurance / permit details (optional)',
      300,
    ),
  };

  static const selections = {
    'languages': [
      'English',
      'Sinhala',
      'Tamil',
    ],
    'workDays': [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ],
    'tools': [
      'Hand tools',
      'Jack and stands',
      'Tyre repair kit',
      'Jump starter',
      'Diagnostic scanner',
      'Recovery truck',
      'Winch',
      'Safety equipment',
    ],
  };

  List<dynamic> _selection(
    String key,
  ) {
    final existing = details[key];

    if (existing is List) {
      return existing;
    }

    final created = <String>[];
    details[key] = created;

    return created;
  }

  IconData _fieldIcon(
    String key,
  ) {
    return switch (key) {
      'businessPhone' =>
        Icons.phone_outlined,
      'businessRegistration' =>
        Icons.business_outlined,
      'workHistory' =>
        Icons.work_history_outlined,
      'qualification' =>
        Icons.workspace_premium_outlined,
      'trainingInstitute' =>
        Icons.school_outlined,
      'qualificationYear' =>
        Icons.calendar_month_outlined,
      'specializations' =>
        Icons.build_outlined,
      'coverageAreas' =>
        Icons.location_city_outlined,
      'radiusKm' =>
        Icons.radar_outlined,
      'startTime' ||
      'endTime' =>
        Icons.schedule_outlined,
      'towRegistration' =>
        Icons.fire_truck_outlined,
      'towCapacityKg' =>
        Icons.scale_outlined,
      'insuranceDetails' =>
        Icons.policy_outlined,
      _ =>
        Icons.edit_note_outlined,
    };
  }

  String? _validateField(
    String key,
    String? raw,
  ) {
    final value =
        raw?.trim() ?? '';

    if (key == 'workHistory' ||
        key == 'insuranceDetails') {
      if (value.isEmpty) {
        return null;
      }
    }

    if (value.isEmpty) {
      return 'Required';
    }

    if (key == 'businessPhone') {
      return validateSriLankaPhone(
        value,
      );
    }

    if (key == 'workHistory' &&
        value.length < 10) {
      return 'Describe your experience in at least 10 characters';
    }

    if (key == 'radiusKm') {
      final parsed =
          int.tryParse(value);

      if (parsed == null ||
          parsed < 1 ||
          parsed > 100) {
        return 'Enter 1 to 100 km';
      }
    }

    if (key == 'qualificationYear') {
      final parsed =
          int.tryParse(value);

      if (parsed == null ||
          (parsed != 0 &&
              (parsed < 1950 ||
                  parsed >
                      DateTime.now().year))) {
        return 'Enter a valid year, or 0';
      }
    }

    if (key == 'towCapacityKg') {
      final parsed =
          int.tryParse(value);

      if (parsed == null ||
          parsed < 500 ||
          parsed > 30000) {
        return 'Enter 500 to 30000 kg';
      }
    }

    if ((key == 'startTime' ||
            key == 'endTime') &&
        !RegExp(
          r'^([01]\d|2[0-3]):[0-5]\d$',
        ).hasMatch(value)) {
      return 'Use HH:mm, for example 08:00';
    }

    if (value.length < 3 &&
        key != 'radiusKm' &&
        key != 'qualificationYear') {
      return 'Provide more detail';
    }

    return null;
  }

  Widget _field(
    BuildContext context,
    String key, {
    int minLines = 1,
    int maxLines = 1,
  }) {
    final config =
        textFields[key]!;

    final numeric = const [
      'radiusKm',
      'qualificationYear',
      'towCapacityKg',
    ].contains(key);

    final controller =
        controllers[key];

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return TextFormField(
      controller: controller,
      enabled: !busy,
      maxLength: config.$2,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: numeric
          ? TextInputType.number
          : key == 'businessPhone'
              ? TextInputType.phone
              : key == 'startTime' ||
                      key == 'endTime'
                  ? TextInputType.datetime
                  : TextInputType.text,
      inputFormatters: numeric
          ? [
              FilteringTextInputFormatter
                  .digitsOnly,
            ]
          : null,
      textCapitalization:
          maxLines > 1
              ? TextCapitalization.sentences
              : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: config.$1,
        prefixIcon: Icon(
          _fieldIcon(key),
        ),
      ),
      validator: (value) {
        return _validateField(
          key,
          value,
        );
      },
    );
  }

  Widget _selectionSection(
    BuildContext context, {
    required String title,
    required String description,
    required String keyName,
    required IconData icon,
  }) {
    final selected =
        _selection(keyName);

    final values =
        selections[keyName] ?? const [];

    return _ProviderProfessionalSurface(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _ProviderProfessionalHeader(
            icon: icon,
            title: title,
            subtitle: description,
          ),

          const SizedBox(height: 13),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(value),
                  selected:
                      selected.contains(value),
                  onSelected: busy
                      ? null
                      : (enabled) {
                          if (enabled) {
                            if (!selected.contains(
                              value,
                            )) {
                              selected.add(
                                value,
                              );
                            }
                          } else {
                            selected.remove(
                              value,
                            );
                          }

                          onChanged();
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerType =
        details['providerType']
                as String? ??
            'independent';

    final available24Hours =
        details['available24Hours'] ==
            true;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _ProviderProfessionalHeader(
          icon:
              Icons.engineering_outlined,
          title:
              'Professional profile',
          subtitle:
              'Provide accurate service, qualification and availability information for manual verification.',
        ),

        const SizedBox(height: 13),

        _ProviderProfessionalSurface(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue:
                    providerType,
                isExpanded: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Provider type',
                  prefixIcon: Icon(
                    Icons
                        .business_center_outlined,
                  ),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value:
                        'independent',
                    child: Text(
                      'Independent technician',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value:
                        'business',
                    child: Text(
                      'Registered service business',
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        details['providerType'] =
                            value;

                        onChanged();
                      },
              ),

              const SizedBox(height: 13),

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                value:
                    available24Hours,
                onChanged: busy
                    ? null
                    : (value) {
                        details[
                                'available24Hours'] =
                            value;

                        onChanged();
                      },
                secondary: Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: available24Hours
                        ? raSuccess
                            .withValues(
                            alpha: .10,
                          )
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    available24Hours
                        ? Icons
                            .schedule_rounded
                        : Icons
                            .schedule_outlined,
                    color: available24Hours
                        ? raSuccess
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),
                title: Text(
                  'Available 24 hours',
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Disable this if you operate within specific working hours.',
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 8.2,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const _ProviderProfessionalSectionTitle(
          title:
              'Contact & experience',
          subtitle:
              'Information used to assess your provider profile.',
        ),

        const SizedBox(height: 10),

        _ProviderProfessionalSurface(
          child: Column(
            children: [
              _field(
                context,
                'businessPhone',
              ),

              if (providerType ==
                  'business') ...[
                const SizedBox(height: 12),

                _field(
                  context,
                  'businessRegistration',
                ),
              ],

              const SizedBox(height: 12),

              _field(
                context,
                'workHistory',
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const _ProviderProfessionalSectionTitle(
          title:
              'Training & capability',
          subtitle:
              'Add qualifications, training and areas of technical experience.',
        ),

        const SizedBox(height: 10),

        _ProviderProfessionalSurface(
          child: Column(
            children: [
              _field(
                context,
                'qualification',
              ),

              const SizedBox(height: 12),

              _field(
                context,
                'trainingInstitute',
              ),

              const SizedBox(height: 12),

              _field(
                context,
                'qualificationYear',
              ),

              const SizedBox(height: 12),

              _field(
                context,
                'specializations',
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const _ProviderProfessionalSectionTitle(
          title: 'Coverage',
          subtitle:
              'Describe the locations and distance you normally serve.',
        ),

        const SizedBox(height: 10),

        _ProviderProfessionalSurface(
          child: Column(
            children: [
              _field(
                context,
                'coverageAreas',
                minLines: 2,
                maxLines: 4,
              ),

              const SizedBox(height: 12),

              _field(
                context,
                'radiusKm',
              ),
            ],
          ),
        ),

        if (!available24Hours) ...[
          const SizedBox(height: 20),

          const _ProviderProfessionalSectionTitle(
            title: 'Working hours',
            subtitle:
                'Use 24-hour time, for example 08:00 and 18:00.',
          ),

          const SizedBox(height: 10),

          _ProviderProfessionalSurface(
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth <
                    330) {
                  return Column(
                    children: [
                      _field(
                        context,
                        'startTime',
                      ),

                      const SizedBox(height: 12),

                      _field(
                        context,
                        'endTime',
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        context,
                        'startTime',
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _field(
                        context,
                        'endTime',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],

        if (towing) ...[
          const SizedBox(height: 20),

          const _ProviderProfessionalSectionTitle(
            title:
                'Recovery vehicle',
            subtitle:
                'Required when Vehicle Towing is selected.',
          ),

          const SizedBox(height: 10),

          _ProviderProfessionalSurface(
            child: Column(
              children: [
                _field(
                  context,
                  'towRegistration',
                ),

                const SizedBox(height: 12),

                _field(
                  context,
                  'towCapacityKg',
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        const _ProviderProfessionalSectionTitle(
          title:
              'Insurance / permits',
          subtitle:
              'Optional additional information about insurance or operating permits.',
        ),

        const SizedBox(height: 10),

        _ProviderProfessionalSurface(
          child: _field(
            context,
            'insuranceDetails',
            minLines: 2,
            maxLines: 4,
          ),
        ),

        const SizedBox(height: 20),

        _selectionSection(
          context,
          title:
              'Languages spoken',
          description:
              'Select languages you can comfortably use with customers.',
          keyName:
              'languages',
          icon:
              Icons.translate_outlined,
        ),

        const SizedBox(height: 12),

        _selectionSection(
          context,
          title:
              'Working days',
          description:
              'Choose the days you normally provide roadside assistance.',
          keyName:
              'workDays',
          icon:
              Icons.calendar_month_outlined,
        ),

        const SizedBox(height: 12),

        _selectionSection(
          context,
          title:
              'Tools & equipment',
          description:
              'Select equipment currently available for roadside jobs.',
          keyName:
              'tools',
          icon:
              Icons.handyman_outlined,
        ),
      ],
    );
  }
}

class _ProviderProfessionalSectionTitle
    extends StatelessWidget {
  const _ProviderProfessionalSectionTitle({
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
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -.2,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.7,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProviderProfessionalHeader
    extends StatelessWidget {
  const _ProviderProfessionalHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withValues(
              alpha: .08,
            ),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colors.primary,
            size: 20,
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
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  height: 1.4,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderProfessionalSurface
    extends StatelessWidget {
  const _ProviderProfessionalSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : colors.surface,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: child,
    );
  }
}