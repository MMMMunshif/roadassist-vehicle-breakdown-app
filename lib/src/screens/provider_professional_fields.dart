part of '../screens.dart';

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
  final bool towing, busy;
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
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      const Text('Service details', style: RaText.headline),
      const Text(
        'Give accurate details so reviewers can assess the services you offer. Practical experience is accepted for review; do not claim qualifications you do not hold.',
      ),
      DropdownButtonFormField<String>(
        initialValue: details['providerType'] as String,
        decoration: const InputDecoration(labelText: 'Provider type'),
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
            : (v) {
                details['providerType'] = v;
                onChanged();
              },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Available 24 hours'),
        value: details['available24Hours'] == true,
        onChanged: busy
            ? null
            : (value) {
                details['available24Hours'] = value;
                onChanged();
              },
      ),
      // Registration asks only for essentials; legacy optional fields remain stored.
      for (final e in textFields.entries)
        if ([
              'businessPhone',
              'businessRegistration',
              'workHistory',
              'radiusKm',
              'startTime',
              'endTime',
              'towRegistration',
              'towCapacityKg',
            ].contains(e.key) &&
            (e.key != 'businessRegistration' ||
                details['providerType'] == 'business') &&
            (!['towRegistration', 'towCapacityKg'].contains(e.key) || towing) &&
            (!['startTime', 'endTime'].contains(e.key) ||
                details['available24Hours'] != true))
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: TextFormField(
              controller: controllers[e.key],
              enabled: !busy,
              maxLength: e.value.$2,
              minLines: e.key == 'workHistory' ? 3 : 1,
              maxLines: e.key == 'workHistory' ? 6 : 1,
              keyboardType:
                  [
                    'radiusKm',
                    'qualificationYear',
                    'towCapacityKg',
                  ].contains(e.key)
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(labelText: e.value.$1),
              validator: (raw) {
                final v = raw?.trim() ?? '';
                if (e.key == 'insuranceDetails') return null;
                if (e.key == 'workHistory' && v.isEmpty) return null;
                if (v.isEmpty) return 'Required';
                if (e.key == 'businessPhone') return validateSriLankaPhone(v);
                if (e.key == 'workHistory' && v.length < 10)
                  return 'Describe your experience in at least 10 characters';
                if (e.key == 'radiusKm' &&
                    (int.tryParse(v) == null ||
                        int.parse(v) < 1 ||
                        int.parse(v) > 100))
                  return 'Enter 1 to 100 km';
                if (e.key == 'qualificationYear' &&
                    (int.tryParse(v) == null ||
                        (int.parse(v) != 0 &&
                            (int.parse(v) < 1950 ||
                                int.parse(v) > DateTime.now().year))))
                  return 'Enter a valid year, or 0';
                if (e.key == 'towCapacityKg' &&
                    (int.tryParse(v) == null ||
                        int.parse(v) < 500 ||
                        int.parse(v) > 30000))
                  return 'Enter the documented capacity, 500 to 30000 kg';
                if (['startTime', 'endTime'].contains(e.key) &&
                    !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v))
                  return 'Use HH:mm, for example 08:00';
                if (v.length < 3 &&
                    !['radiusKm', 'qualificationYear'].contains(e.key))
                  return 'Provide more detail';
                return null;
              },
            ),
          ),
      const SizedBox(height: 12),
      const Text('Languages spoken', style: RaText.title),
      Wrap(
        spacing: 8,
        children: [
          for (final language in selections['languages']!)
            FilterChip(
              label: Text(language),
              selected: (details['languages'] as List).contains(language),
              onSelected: busy
                  ? null
                  : (selected) {
                      final languages = details['languages'] as List;
                      if (selected) {
                        languages.add(language);
                      } else {
                        languages.remove(language);
                      }
                      onChanged();
                    },
            ),
        ],
      ),
      const SizedBox(height: 20),
    ],
  );
}
