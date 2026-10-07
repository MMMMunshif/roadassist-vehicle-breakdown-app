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
    'businessPhone': ('Service contact phone', 16),
    'businessRegistration': ('Business registration number', 60),
    'workHistory': ('Brief work experience (optional)', 1000),
    'qualification': ('Qualification or practical training completed', 150),
    'trainingInstitute': (
      'Training institute / on-the-job training workplace',
      150,
    ),
    'qualificationYear': ('Training completion year (0 if ongoing)', 4),
    'specializations': (
      'Specializations, vehicle makes and systems you repair',
      300,
    ),
    'coverageAreas': ('Towns / districts you cover', 300),
    'radiusKm': ('Maximum service radius (km)', 3),
    'startTime': ('Start time (24-hour HH:mm)', 5),
    'endTime': ('End time (24-hour HH:mm; may end next day)', 5),
    'towRegistration': ('Recovery vehicle registration', 20),
    'towCapacityKg': ('Maximum safe recovery capacity (kg)', 5),
    'insuranceDetails': ('Insurance / permit details (optional)', 300),
  };

  static const selections = {
    'languages': ['English', 'Sinhala', 'Tamil'],
    'workDays': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
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

  IconData _fieldIcon(String key) {
    return switch (key) {
      'businessPhone' => Icons.phone_outlined,
      'businessRegistration' => Icons.business_outlined,
      'workHistory' => Icons.work_history_outlined,
      'radiusKm' => Icons.radar_outlined,
      'startTime' || 'endTime' => Icons.schedule_outlined,
      'towRegistration' => Icons.fire_truck_outlined,
      'towCapacityKg' => Icons.scale_outlined,
      _ => Icons.edit_note_outlined,
    };
  }

  List<dynamic> _selection(String key) {
    final value = details[key];

    if (value is List) {
      return value;
    }

    final created = <String>[];
    details[key] = created;
    return created;
  }

  Widget _selectionSection(
    BuildContext context, {
    required String title,
    required String description,
    required String keyName,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selection(keyName);

    return Container(
      padding: const EdgeInsets.all(RaSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.md),
          Wrap(
            spacing: RaSpace.sm,
            runSpacing: RaSpace.sm,
            children: [
              for (final value in selections[keyName]!)
                FilterChip(
                  label: Text(value),
                  selected: selected.contains(value),
                  onSelected: busy
                      ? null
                      : (enabled) {
                          if (enabled) {
                            if (!selected.contains(value)) {
                              selected.add(value);
                            }
                          } else {
                            selected.remove(value);
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final providerType =
        details['providerType'] as String? ?? 'independent';

    final available24Hours =
        details['available24Hours'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: RaSpace.xl),

        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.engineering_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Professional details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Provide accurate information about how and where you offer roadside services.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: RaSpace.lg),

        Container(
          padding: const EdgeInsets.all(RaSpace.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: providerType,
                decoration: const InputDecoration(
                  labelText: 'Provider type',
                  prefixIcon: Icon(Icons.business_center_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'independent',
                    child: Text('Independent technician'),
                  ),
                  DropdownMenuItem(
                    value: 'business',
                    child: Text('Registered service business'),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;

                        details['providerType'] = value;
                        onChanged();
                      },
              ),

              const SizedBox(height: RaSpace.md),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: available24Hours
                        ? raSuccess.withValues(alpha: .10)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.schedule_outlined,
                    color: available24Hours
                        ? raSuccess
                        : colors.onSurfaceVariant,
                  ),
                ),
                title: const Text(
                  'Available 24 hours',
                  style: RaText.title,
                ),
                subtitle: const Text(
                  'Disable this to enter specific working hours.',
                ),
                value: available24Hours,
                onChanged: busy
                    ? null
                    : (value) {
                        details['available24Hours'] = value;
                        onChanged();
                      },
              ),
            ],
          ),
        ),

        for (final entry in textFields.entries)
          if ([
                'businessPhone',
                'businessRegistration',
                'workHistory',
                'radiusKm',
                'startTime',
                'endTime',
                'towRegistration',
                'towCapacityKg',
              ].contains(entry.key) &&
              (entry.key != 'businessRegistration' ||
                  providerType == 'business') &&
              (!['towRegistration', 'towCapacityKg'].contains(entry.key) ||
                  towing) &&
              (!['startTime', 'endTime'].contains(entry.key) ||
                  !available24Hours))
            Padding(
              padding: const EdgeInsets.only(top: RaSpace.md),
              child: TextFormField(
                controller: controllers[entry.key],
                enabled: !busy,
                maxLength: entry.value.$2,
                minLines: entry.key == 'workHistory' ? 3 : 1,
                maxLines: entry.key == 'workHistory' ? 6 : 1,
                keyboardType: [
                  'radiusKm',
                  'qualificationYear',
                  'towCapacityKg',
                ].contains(entry.key)
                    ? TextInputType.number
                    : entry.key == 'businessPhone'
                    ? TextInputType.phone
                    : TextInputType.text,
                textCapitalization: entry.key == 'workHistory'
                    ? TextCapitalization.sentences
                    : TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: entry.value.$1,
                  prefixIcon: Icon(_fieldIcon(entry.key)),
                ),
                validator: (raw) {
                  final value = raw?.trim() ?? '';

                  if (entry.key == 'insuranceDetails') {
                    return null;
                  }

                  if (entry.key == 'workHistory' && value.isEmpty) {
                    return null;
                  }

                  if (value.isEmpty) {
                    return 'Required';
                  }

                  if (entry.key == 'businessPhone') {
                    return validateSriLankaPhone(value);
                  }

                  if (entry.key == 'workHistory' && value.length < 10) {
                    return 'Describe your experience in at least 10 characters';
                  }

                  if (entry.key == 'radiusKm' &&
                      (int.tryParse(value) == null ||
                          int.parse(value) < 1 ||
                          int.parse(value) > 100)) {
                    return 'Enter 1 to 100 km';
                  }

                  if (entry.key == 'qualificationYear' &&
                      (int.tryParse(value) == null ||
                          (int.parse(value) != 0 &&
                              (int.parse(value) < 1950 ||
                                  int.parse(value) > DateTime.now().year)))) {
                    return 'Enter a valid year, or 0';
                  }

                  if (entry.key == 'towCapacityKg' &&
                      (int.tryParse(value) == null ||
                          int.parse(value) < 500 ||
                          int.parse(value) > 30000)) {
                    return 'Enter the documented capacity, 500 to 30000 kg';
                  }

                  if (['startTime', 'endTime'].contains(entry.key) &&
                      !RegExp(
                        r'^([01]\d|2[0-3]):[0-5]\d$',
                      ).hasMatch(value)) {
                    return 'Use HH:mm, for example 08:00';
                  }

                  if (value.length < 3 &&
                      !['radiusKm', 'qualificationYear'].contains(entry.key)) {
                    return 'Provide more detail';
                  }

                  return null;
                },
              ),
            ),

        const SizedBox(height: RaSpace.lg),

        _selectionSection(
          context,
          title: 'Languages spoken',
          description:
              'Select languages you can comfortably use with customers.',
          keyName: 'languages',
          icon: Icons.translate_outlined,
        ),

        const SizedBox(height: RaSpace.md),

        _selectionSection(
          context,
          title: 'Working days',
          description:
              'Choose the days you normally provide roadside services.',
          keyName: 'workDays',
          icon: Icons.calendar_month_outlined,
        ),

        const SizedBox(height: RaSpace.md),

        _selectionSection(
          context,
          title: 'Tools & equipment',
          description:
              'Select equipment you currently have available for jobs.',
          keyName: 'tools',
          icon: Icons.handyman_outlined,
        ),

        const SizedBox(height: RaSpace.lg),
      ],
    );
  }
}