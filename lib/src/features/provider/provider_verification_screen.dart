part of '../../screens.dart';

class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({
    super.key,
    this.application,
    this.moderation,
  });
  final Map<String, dynamic>? application, moderation;
  @override
  State<ProviderVerificationScreen> createState() =>
      _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState
    extends State<ProviderVerificationScreen> {
  final form = GlobalKey<FormState>();
  final professionalControllers = {
    for (final key in _ProviderProfessionalFields.textFields.keys)
      key: TextEditingController(),
  };
  final professional = <String, dynamic>{
    'providerType': 'independent',
    'available24Hours': false,
    'languages': <String>[],
    'workDays': <String>[],
    'tools': <String>[],
  };
  final name = TextEditingController(),
      nic = TextEditingController(),
      address = TextEditingController();
  final business = TextEditingController(),
      emergency = TextEditingController(),
      experience = TextEditingController();
  final photos = <String, String>{};
  final services = <String>{}, vehicleTypes = <String>{};
  bool consent = false, busy = false;
  String? error;
  static const documents = {
    'businessProof': 'Business registration document (registered business)',
    'nicFront': 'NIC front',
    'nicBack': 'NIC back',
    'selfie': 'Recent face photo',
    'serviceProof': 'Qualification / business / service experience proof',
    'recoveryProof': 'Recovery vehicle registration / authorization (towing)',
  };
  @override
  void initState() {
    super.initState();
    final a = widget.application;
    final saved = Map<String, dynamic>.from(
      a?['professionalDetails'] as Map? ?? {},
    );
    for (final e in professionalControllers.entries) {
      e.value.text =
          '${saved[e.key] ?? {'radiusKm': 15, 'qualificationYear': 0, 'towCapacityKg': 0, 'startTime': '', 'endTime': ''}[e.key] ?? ''}';
    }
    for (final key in ['providerType', 'available24Hours']) {
      if (saved[key] != null) professional[key] = saved[key];
    }
    for (final key in _ProviderProfessionalFields.selections.keys) {
      professional[key] = List<String>.from(saved[key] as List? ?? []);
    }
    name.text = a?['legalName'] as String? ?? '';
    unawaited(prefillContact());
    nic.text = a?['nicNumber'] as String? ?? '';
    address.text = a?['address'] as String? ?? '';
    business.text = a?['businessName'] as String? ?? '';
    emergency.text = a?['emergencyPhone'] as String? ?? '';
    experience.text = '${a?['experienceYears'] ?? 0}';
    services.addAll((a?['services'] as List? ?? []).cast<String>());
    vehicleTypes.addAll((a?['vehicleTypes'] as List? ?? []).cast<String>());
    photos.addAll(Map<String, String>.from(a?['documents'] as Map? ?? {}));
  }

  @override
  void dispose() {
    for (final c in [name, nic, address, business, emergency, experience]) {
      c.dispose();
    }
    for (final c in professionalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> prefillContact() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      if (!mounted) return;
      final data = profile.data();
      if (name.text.isEmpty) name.text = data?['displayName'] as String? ?? '';
      if (professionalControllers['businessPhone']!.text.isEmpty) {
        professionalControllers['businessPhone']!.text =
            data?['phone'] as String? ?? '';
      }
    } catch (_) {
      /* Contact fields remain editable if profile loading fails. */
    }
  }

  Future<void> pick(String kind) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final prepared = await PhotoUploadService().prepareIdentityPhoto(photo);
      if (mounted) setState(() => photos[kind] = prepared);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Choose a clear JPG or PNG photo, under 8 MB.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    final needed = [
      'nicFront',
      'nicBack',
      'selfie',
      'serviceProof',
      if (services.contains('Vehicle Towing')) 'recoveryProof',
      if (professional['providerType'] == 'business') 'businessProof',
    ];
    if (!consent ||
        services.isEmpty ||
        vehicleTypes.isEmpty ||
        needed.any((k) => !photos.containsKey(k))) {
      setState(
        () => error =
            'Select services and vehicles, upload all required documents, and accept the declaration.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ProviderVerificationService().submit({
        'professionalDetails': {
          ...professional,
          for (final e in professionalControllers.entries)
            e.key:
                [
                  'radiusKm',
                  'qualificationYear',
                  'towCapacityKg',
                ].contains(e.key)
                ? (int.tryParse(e.value.text.trim()) ?? 0)
                : e.key == 'businessPhone'
                ? normalizeSriLankaPhone(e.value.text)
                : e.value.text.trim(),
        },
        'legalName': name.text.trim(),
        'nicNumber': nic.text.trim().toUpperCase(),
        'address': address.text.trim(),
        'businessName': business.text.trim(),
        'emergencyPhone': normalizeSriLankaPhone(emergency.text),
        'experienceYears': int.parse(experience.text),
        'services': services.toList(),
        'vehicleTypes': vehicleTypes.toList(),
        'documents': photos,
      });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not submit. Verify your email and check your connection; an application under review cannot be edited.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.application, m = widget.moderation;
    final changesRequested =
        a != null &&
        m?['verification'] == 'pending' &&
        ((m?['updatedAt'] as Timestamp?)?.toDate().isAfter(
              ((a['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
            ) ??
            false);
    final canEdit =
        a == null || a['professionalDetails'] is! Map || changesRequested;
    final verified = FirebaseAuth.instance.currentUser?.emailVerified == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider verification'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) replace(context, const WelcomeScreen());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.verified_user_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            a == null
                ? 'Apply to become a provider'
                : changesRequested
                ? 'Update your application'
                : 'Your application status',
            style: RaText.headline,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your dashboard and assistance jobs unlock after a reviewer verifies your identity and service capability. Verification is a manual review, not a guarantee of service quality.',
          ),
          if (!verified) ...[
            const SizedBox(height: 16),
            const Text('Verify your email before submitting.'),
            OutlinedButton(
              onPressed: () => push(
                context,
                const EmailVerificationScreen(role: 'provider'),
              ),
              child: const Text('Verify email'),
            ),
          ],
          if (a != null &&
              m?['verification'] == 'verified' &&
              !((m?['validUntil'] as Timestamp?)?.toDate().isAfter(
                    DateTime.now(),
                  ) ??
                  false))
            const Text(
              'Approval expired or requires renewal. Contact support to request document review.',
            ),
          if (a != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdminStatusBadge(
                      status: m?['verification'] as String? ?? 'pending',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m?['reason'] as String? ??
                          'Submitted. Waiting for an administrator to review your documents.',
                    ),
                    if (m?['validUntil'] is Timestamp)
                      Text(
                        'Approval expires: ${(m!['validUntil'] as Timestamp).toDate().toLocal().toString().split(' ').first}',
                      ),
                    if (!canEdit)
                      const Text(
                        'Documents are locked while under review. Contact support for changes or renewal.',
                      ),
                  ],
                ),
              ),
            ),
          if (canEdit)
            Form(
              key: form,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  for (final pair in [
                    (name, 'Full name as shown on NIC', 100),
                    (nic, 'NIC number', 12),
                    (address, 'Residential / business address', 300),
                    if (professional['providerType'] == 'business')
                      (business, 'Business name', 100),
                    (emergency, 'Emergency contact phone (optional)', 16),
                    (experience, 'Years of service experience', 2),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: pair.$1,
                        maxLength: pair.$3,
                        decoration: InputDecoration(labelText: pair.$2),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (pair.$1 == emergency && v.isEmpty) return null;
                          if (v.isEmpty) return 'Required';
                          if (pair.$1 == nic &&
                              !RegExp(r'^(\d{9}[VXvx]|\d{12})$').hasMatch(v))
                            return 'Enter a valid NIC format';
                          if (pair.$1 == emergency)
                            return validateSriLankaPhone(v);
                          if (pair.$1 == experience &&
                              (int.tryParse(v) == null ||
                                  int.parse(v) > 60 ||
                                  int.parse(v) < 0))
                            return 'Enter 0 to 60';
                          return null;
                        },
                      ),
                    ),
                  _ProviderProfessionalFields(
                    controllers: professionalControllers,
                    details: professional,
                    onChanged: () => setState(() {}),
                    towing: services.contains('Vehicle Towing'),
                    busy: busy,
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Services you can provide',
                      style: RaText.title,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final v in [
                        'General Mechanic',
                        'Vehicle Towing',
                        'Flat Tyre',
                        'Battery Jumpstart',
                      ])
                        FilterChip(
                          label: Text(v),
                          selected: services.contains(v),
                          onSelected: busy
                              ? null
                              : (yes) => setState(() {
                                  if (yes) {
                                    services.add(v);
                                  } else {
                                    services.remove(v);
                                  }
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Supported vehicles', style: RaText.title),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final v in [
                        'Sedan / Hatchback',
                        'SUV',
                        'Van',
                        'Motorcycle',
                        'Other',
                      ])
                        FilterChip(
                          label: Text(v),
                          selected: vehicleTypes.contains(v),
                          onSelected: busy
                              ? null
                              : (yes) => setState(() {
                                  if (yes) {
                                    vehicleTypes.add(v);
                                  } else {
                                    vehicleTypes.remove(v);
                                  }
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload clear photos with readable text. Identity documents are private to you and authorized reviewers; they are never shown to drivers.',
                  ),
                  for (final e in documents.entries.where(
                    (e) =>
                        (e.key != 'businessProof' ||
                            professional['providerType'] == 'business') &&
                        (e.key != 'recoveryProof' ||
                            services.contains('Vehicle Towing')),
                  ))
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(e.value),
                            trailing: Icon(
                              photos.containsKey(e.key)
                                  ? Icons.check_circle
                                  : Icons.upload_file,
                            ),
                            onTap: busy ? null : () => pick(e.key),
                          ),
                          if (photos[e.key] != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: _privateDocumentPreview(
                                photos[e.key]!,
                                130,
                              ),
                            ),
                        ],
                      ),
                    ),
                  CheckboxListTile(
                    value: consent,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'I confirm these documents are mine, details are accurate, and I authorize private verification. I will request driver approval before extra work or charges.',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || !verified ? null : submit,
                    child: const Text('Submit for verification'),
                  ),
                ],
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                push(context, const SupportScreen(isProvider: true)),
            child: const Text('Contact support'),
          ),
        ],
      ),
    );
  }
}
