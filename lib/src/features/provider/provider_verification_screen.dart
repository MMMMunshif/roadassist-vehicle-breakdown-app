part of '../../screens.dart';

class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({
    super.key,
    this.application,
    this.moderation,
  });

  final Map<String, dynamic>? application;
  final Map<String, dynamic>? moderation;

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

  final name = TextEditingController();
  final nic = TextEditingController();
  final address = TextEditingController();

  final business = TextEditingController();
  final emergency = TextEditingController();
  final experience = TextEditingController();

  final photos = <String, String>{};
  final services = <String>{};
  final vehicleTypes = <String>{};

  bool consent = false;
  bool busy = false;

  String? error;

  static const documents = {
    'businessProof':
        'Business registration document',
    'nicFront': 'NIC front',
    'nicBack': 'NIC back',
    'selfie': 'Recent face photo',
    'serviceProof':
        'Qualification / business / service experience proof',
    'recoveryProof':
        'Recovery vehicle registration / authorization',
  };

  @override
  void initState() {
    super.initState();

    final application = widget.application;

    final saved = Map<String, dynamic>.from(
      application?['professionalDetails'] as Map? ?? {},
    );

    for (final entry in professionalControllers.entries) {
      entry.value.text =
          '${saved[entry.key] ?? {
                'radiusKm': 15,
                'qualificationYear': 0,
                'towCapacityKg': 0,
                'startTime': '',
                'endTime': '',
              }[entry.key] ?? ''}';
    }

    for (final key in [
      'providerType',
      'available24Hours',
    ]) {
      if (saved[key] != null) {
        professional[key] = saved[key];
      }
    }

    for (final key in _ProviderProfessionalFields.selections.keys) {
      professional[key] = List<String>.from(
        saved[key] as List? ?? [],
      );
    }

    name.text =
        application?['legalName'] as String? ?? '';

    nic.text =
        application?['nicNumber'] as String? ?? '';

    address.text =
        application?['address'] as String? ?? '';

    business.text =
        application?['businessName'] as String? ?? '';

    emergency.text =
        application?['emergencyPhone'] as String? ?? '';

    experience.text =
        '${application?['experienceYears'] ?? 0}';

    services.addAll(
      (application?['services'] as List? ?? []).cast<String>(),
    );

    vehicleTypes.addAll(
      (application?['vehicleTypes'] as List? ?? []).cast<String>(),
    );

    photos.addAll(
      Map<String, String>.from(
        application?['documents'] as Map? ?? {},
      ),
    );

    unawaited(prefillContact());
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      nic,
      address,
      business,
      emergency,
      experience,
    ]) {
      controller.dispose();
    }

    for (final controller in professionalControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> prefillContact() async {
    try {
      final profile =
          await AuthService().getCurrentProfile();

      if (!mounted) return;

      final data = profile.data();

      if (name.text.isEmpty) {
        name.text =
            data?['displayName'] as String? ?? '';
      }

      if (professionalControllers['businessPhone']!
          .text
          .isEmpty) {
        professionalControllers['businessPhone']!.text =
            data?['phone'] as String? ?? '';
      }
    } catch (_) {
      // Fields remain editable if profile loading fails.
    }
  }

  Future<void> pick(String kind) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final prepared =
          await PhotoUploadService().prepareIdentityPhoto(
        photo,
      );

      if (!mounted) return;

      setState(() {
        photos[kind] = prepared;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'Choose a clear JPG or PNG photo under 8 MB.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();

    if (!(form.currentState?.validate() ?? false)) {
      return;
    }

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
        needed.any((key) => !photos.containsKey(key))) {
      setState(() {
        error =
            'Select services and supported vehicles, upload all required documents, and accept the declaration.';
      });

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
          for (final entry in professionalControllers.entries)
            entry.key: [
                  'radiusKm',
                  'qualificationYear',
                  'towCapacityKg',
                ].contains(entry.key)
                ? (int.tryParse(entry.value.text.trim()) ?? 0)
                : entry.key == 'businessPhone'
                ? normalizeSriLankaPhone(entry.value.text)
                : entry.value.text.trim(),
        },
        'legalName': name.text.trim(),
        'nicNumber': nic.text.trim().toUpperCase(),
        'address': address.text.trim(),
        'businessName': business.text.trim(),
        'emergencyPhone': normalizeSriLankaPhone(
          emergency.text,
        ),
        'experienceYears': int.parse(
          experience.text,
        ),
        'services': services.toList(),
        'vehicleTypes': vehicleTypes.toList(),
        'documents': photos,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provider verification application submitted.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not submit. Verify your email and connection. An application already under review cannot be edited.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  IconData _serviceIcon(String service) {
    return switch (service) {
      'Vehicle Towing' => Icons.fire_truck_outlined,
      'Battery Jumpstart' => Icons.battery_charging_full,
      'Flat Tyre' => Icons.tire_repair,
      _ => Icons.car_repair_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final application = widget.application;
    final moderation = widget.moderation;

    final submittedAt =
        (application?['submittedAt'] as Timestamp?)?.toDate();

    final moderationUpdated =
        (moderation?['updatedAt'] as Timestamp?)?.toDate();

    final changesRequested =
        application != null &&
        moderation?['verification'] == 'pending' &&
        moderationUpdated != null &&
        moderationUpdated.isAfter(
          submittedAt ?? DateTime.now(),
        );

    final canEdit =
        application == null ||
        application['professionalDetails'] is! Map ||
        changesRequested;

    final verifiedEmail =
        FirebaseAuth.instance.currentUser?.emailVerified == true;

    final verification =
        moderation?['verification'] as String? ?? 'pending';

    final validUntil =
        (moderation?['validUntil'] as Timestamp?)?.toDate();

    final expiredApproval =
        application != null &&
        verification == 'verified' &&
        !(validUntil?.isAfter(DateTime.now()) ?? false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Provider Verification'),
        actions: [
          IconButton(
            tooltip: 'Help & support',
            onPressed: () => push(
              context,
              const SupportScreen(isProvider: true),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthService().signOut();

              if (context.mounted) {
                replace(
                  context,
                  const WelcomeScreen(),
                );
              }
            },
          ),
          const SizedBox(width: RaSpace.xs),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(RaSpace.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  const Color(0xFF007D70),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(height: RaSpace.lg),
                Text(
                  application == null
                      ? 'Become a verified RoadAssist provider'
                      : changesRequested
                      ? 'Update your provider application'
                      : 'Provider verification status',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Your provider dashboard and assistance jobs unlock after identity and service capability review.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RaSpace.md),

          Container(
            padding: const EdgeInsets.all(RaSpace.md),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: .38),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                ),
                SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Text(
                    'Verification is a manual account review. Approval confirms that submitted information was reviewed; it is not a guarantee of service quality.',
                  ),
                ),
              ],
            ),
          ),

          if (!verifiedEmail) ...[
            const SizedBox(height: RaSpace.md),

            Container(
              padding: const EdgeInsets.all(RaSpace.lg),
              decoration: BoxDecoration(
                color:
                    raGold.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      raGold.withValues(alpha: .25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        color: raGold,
                      ),
                      SizedBox(width: RaSpace.sm),
                      Expanded(
                        child: Text(
                          'Email verification required',
                          style: RaText.title,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const Text(
                    'Verify your email before submitting the provider application.',
                    style: RaText.bodyMuted,
                  ),
                  const SizedBox(height: RaSpace.md),
                  OutlinedButton.icon(
                    onPressed: () => push(
                      context,
                      const EmailVerificationScreen(
                        role: 'provider',
                      ),
                    ),
                    icon: const Icon(
                      Icons.forward_to_inbox_outlined,
                    ),
                    label: const Text('Verify Email'),
                  ),
                ],
              ),
            ),
          ],

          if (expiredApproval) ...[
            const SizedBox(height: RaSpace.md),

            Container(
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: raGoldPale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    color: raGold,
                  ),
                  SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: Text(
                      'Your previous provider approval has expired or requires renewal. Contact support for document review.',
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (application != null) ...[
            const SizedBox(height: RaSpace.lg),

            Container(
              padding: const EdgeInsets.all(RaSpace.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Application status',
                          style: RaText.title,
                        ),
                      ),
                      _AdminStatusBadge(
                        status: verification,
                      ),
                    ],
                  ),

                  const SizedBox(height: RaSpace.md),

                  Text(
                    moderation?['reason'] as String? ??
                        'Submitted. Waiting for an authorized reviewer to assess your documents.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                  ),

                  if (validUntil != null) ...[
                    const SizedBox(height: RaSpace.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: RaSpace.sm),
                        Expanded(
                          child: Text(
                            'Approval expires: ${validUntil.toLocal().toString().split(' ').first}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (!canEdit) ...[
                    const SizedBox(height: RaSpace.md),
                    Container(
                      padding: const EdgeInsets.all(RaSpace.md),
                      decoration: BoxDecoration(
                        color: colors
                            .surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                          ),
                          SizedBox(width: RaSpace.sm),
                          Expanded(
                            child: Text(
                              'Documents are locked while the application is under review. Contact support if changes are required.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (canEdit) ...[
            const SizedBox(height: RaSpace.xxl),

            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProviderVerificationSection(
                    title: 'Identity & contact',
                    subtitle:
                        'Enter information exactly as it appears on your identification documents.',
                    icon: Icons.badge_outlined,
                    child: Column(
                      children: [
                        for (final pair in [
                          (
                            name,
                            'Full name as shown on NIC',
                            100,
                            Icons.person_outline_rounded,
                          ),
                          (
                            nic,
                            'NIC number',
                            12,
                            Icons.badge_outlined,
                          ),
                          (
                            address,
                            'Residential / business address',
                            300,
                            Icons.location_on_outlined,
                          ),
                          if (professional['providerType'] == 'business')
                            (
                              business,
                              'Business name',
                              100,
                              Icons.business_outlined,
                            ),
                          (
                            emergency,
                            'Emergency contact phone (optional)',
                            16,
                            Icons.contact_emergency_outlined,
                          ),
                          (
                            experience,
                            'Years of service experience',
                            2,
                            Icons.work_history_outlined,
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: RaSpace.md,
                            ),
                            child: TextFormField(
                              controller: pair.$1,
                              enabled: !busy,
                              maxLength: pair.$3,
                              keyboardType:
                                  pair.$1 == emergency
                                  ? TextInputType.phone
                                  : pair.$1 == experience
                                  ? TextInputType.number
                                  : TextInputType.text,
                              textCapitalization:
                                  pair.$1 == name ||
                                      pair.$1 == address ||
                                      pair.$1 == business
                                  ? TextCapitalization.words
                                  : TextCapitalization.none,
                              decoration: InputDecoration(
                                labelText: pair.$2,
                                prefixIcon: Icon(pair.$4),
                              ),
                              validator: (value) {
                                final text =
                                    value?.trim() ?? '';

                                if (pair.$1 == emergency &&
                                    text.isEmpty) {
                                  return null;
                                }

                                if (text.isEmpty) {
                                  return 'Required';
                                }

                                if (pair.$1 == nic &&
                                    !RegExp(
                                      r'^(\d{9}[VXvx]|\d{12})$',
                                    ).hasMatch(text)) {
                                  return 'Enter a valid NIC format';
                                }

                                if (pair.$1 == emergency) {
                                  return validateSriLankaPhone(text);
                                }

                                if (pair.$1 == experience &&
                                    (int.tryParse(text) == null ||
                                        int.parse(text) > 60 ||
                                        int.parse(text) < 0)) {
                                  return 'Enter 0 to 60';
                                }

                                return null;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  _ProviderProfessionalFields(
                    controllers: professionalControllers,
                    details: professional,
                    onChanged: () {
                      setState(() {});
                    },
                    towing: services.contains('Vehicle Towing'),
                    busy: busy,
                  ),

                  _ProviderVerificationSection(
                    title: 'Services offered',
                    subtitle:
                        'Only select services you are currently able to provide.',
                    icon: Icons.car_repair_outlined,
                    child: Wrap(
                      spacing: RaSpace.sm,
                      runSpacing: RaSpace.sm,
                      children: [
                        for (final service in [
                          'General Mechanic',
                          'Vehicle Towing',
                          'Flat Tyre',
                          'Battery Jumpstart',
                        ])
                          FilterChip(
                            avatar: Icon(
                              _serviceIcon(service),
                              size: 17,
                            ),
                            label: Text(service),
                            selected: services.contains(service),
                            onSelected: busy
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        services.add(service);
                                      } else {
                                        services.remove(service);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  _ProviderVerificationSection(
                    title: 'Supported vehicles',
                    subtitle:
                        'Select vehicle categories you can safely service.',
                    icon: Icons.directions_car_outlined,
                    child: Wrap(
                      spacing: RaSpace.sm,
                      runSpacing: RaSpace.sm,
                      children: [
                        for (final vehicle in [
                          'Sedan / Hatchback',
                          'SUV',
                          'Van',
                          'Motorcycle',
                          'Other',
                        ])
                          FilterChip(
                            label: Text(vehicle),
                            selected: vehicleTypes.contains(vehicle),
                            onSelected: busy
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        vehicleTypes.add(vehicle);
                                      } else {
                                        vehicleTypes.remove(vehicle);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RaSpace.xxl),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification documents',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Upload clear images with readable text.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${photos.length} uploaded',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: RaSpace.sm),

                  Container(
                    padding: const EdgeInsets.all(RaSpace.md),
                    decoration: BoxDecoration(
                      color: colors
                          .surfaceContainerHighest
                          .withValues(alpha: .34),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          size: 19,
                        ),
                        SizedBox(width: RaSpace.sm),
                        Expanded(
                          child: Text(
                            'Identity documents are private to you and authorized reviewers. They are not displayed to drivers.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  for (final entry in documents.entries.where(
                    (entry) =>
                        (entry.key != 'businessProof' ||
                            professional['providerType'] == 'business') &&
                        (entry.key != 'recoveryProof' ||
                            services.contains('Vehicle Towing')),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: RaSpace.sm,
                      ),
                      child: _ProviderDocumentCard(
                        title: entry.value,
                        uploaded: photos.containsKey(entry.key),
                        previewData: photos[entry.key],
                        busy: busy,
                        onTap: () => pick(entry.key),
                      ),
                    ),

                  const SizedBox(height: RaSpace.lg),

                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .55),
                      ),
                    ),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.all(RaSpace.md),
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      value: consent,
                      onChanged: busy
                          ? null
                          : (value) {
                              setState(() {
                                consent = value ?? false;
                              });
                            },
                      title: const Text(
                        'Declaration & approval',
                        style: RaText.title,
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          'I confirm that these documents are mine, the information is accurate, and I authorize private verification. I will request driver approval before additional work or charges.',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: RaSpace.lg),

                  FilledButton.icon(
                    onPressed:
                        busy || !verifiedEmail ? null : submit,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.verified_outlined,
                          ),
                    label: Text(
                      busy
                          ? 'Submitting Application…'
                          : application == null
                          ? 'Submit for Verification'
                          : 'Submit Updated Application',
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (busy) ...[
            const SizedBox(height: RaSpace.md),
            const LinearProgressIndicator(),
          ],

          if (error != null) ...[
            const SizedBox(height: RaSpace.md),
            Container(
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.error,
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: RaSpace.xl),

          OutlinedButton.icon(
            onPressed: () => push(
              context,
              const SupportScreen(isProvider: true),
            ),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }
}

class _ProviderVerificationSection extends StatelessWidget {
  const _ProviderVerificationSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(
        bottom: RaSpace.md,
      ),
      padding: const EdgeInsets.all(RaSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 21,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
          child,
        ],
      ),
    );
  }
}

class _ProviderDocumentCard extends StatelessWidget {
  const _ProviderDocumentCard({
    required this.title,
    required this.uploaded,
    required this.previewData,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final bool uploaded;
  final String? previewData;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: uploaded
              ? raSuccess.withValues(alpha: .32)
              : colors.outlineVariant.withValues(alpha: .55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RaSpace.md,
              vertical: 5,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: uploaded
                    ? raSuccess.withValues(alpha: .10)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                uploaded
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_outlined,
                color:
                    uploaded ? raSuccess : colors.onSurfaceVariant,
              ),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              uploaded
                  ? 'Document added'
                  : 'Tap to choose an image',
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
            ),
            onTap: busy ? null : onTap,
          ),
          if (previewData != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.md,
                0,
                RaSpace.md,
                RaSpace.md,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _privateDocumentPreview(
                  previewData!,
                  150,
                ),
              ),
            ),
        ],
      ),
    );
  }
}