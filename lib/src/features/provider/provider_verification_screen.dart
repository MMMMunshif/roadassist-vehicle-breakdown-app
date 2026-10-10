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
  final customServices = <Map<String, String>>[];
  bool applyAgain = false;

  final vehicleTypes = <String>{};

  bool consent = false;
  bool busy = false;
  bool submittedThisSession = false;
  bool dirty = false;

  String? error;

  static const documents = {
    'businessProof': 'Business registration document',
    'nicFront': 'NIC front',
    'nicBack': 'NIC back',
    'selfie': 'Provider selfie (clear face photo)',
    'serviceProof': 'Qualification / business / service experience proof',
    'recoveryProof': 'Recovery vehicle registration / authorization',
  };

  static const serviceOptions = [
    'General Mechanic',
    'Vehicle Towing',
    'Flat Tyre',
    'Battery Jumpstart',
  ];

  static const vehicleOptions = [
    'Sedan / Hatchback',
    'SUV',
    'Van',
    'Motorcycle',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final application = widget.application;

    final saved = Map<String, dynamic>.from(
      application?['professionalDetails'] as Map? ?? {},
    );

    for (final entry in professionalControllers.entries) {
      final value = saved[entry.key];

      entry.value.text = value == null ? '' : '$value';
    }

    if (saved['providerType'] != null) {
      professional['providerType'] = saved['providerType'];
    }

    if (saved['available24Hours'] != null) {
      professional['available24Hours'] = saved['available24Hours'];
    }

    for (final key in _ProviderProfessionalFields.selections.keys) {
      professional[key] = List<String>.from(saved[key] as List? ?? const []);
    }

    name.text = application?['legalName'] as String? ?? '';

    nic.text = application?['nicNumber'] as String? ?? '';

    address.text = application?['address'] as String? ?? '';

    business.text = application?['businessName'] as String? ?? '';

    emergency.text = application?['emergencyPhone'] as String? ?? '';

    final savedExperience = application?['experienceYears'];

    experience.text = savedExperience == null ? '' : '$savedExperience';

    services.addAll(
      (application?['services'] as List? ?? const []).whereType<String>(),
    );

    customServices.addAll(
      (application?['customServices'] as List? ?? []).whereType<Map>().map(
        (item) => Map<String, String>.from(item),
      ),
    );

    vehicleTypes.addAll(
      (application?['vehicleTypes'] as List? ?? const []).whereType<String>(),
    );

    photos.addAll(
      Map<String, String>.from(application?['documents'] as Map? ?? {}),
    );

    unawaited(prefillContact());
  }

  @override
  void dispose() {
    name.dispose();
    nic.dispose();
    address.dispose();
    business.dispose();
    emergency.dispose();
    experience.dispose();

    for (final controller in professionalControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> prefillContact() async {
    try {
      final profile = await AuthService().getCurrentProfile();

      if (!mounted) return;

      final data = profile.data();

      if (name.text.trim().isEmpty) {
        name.text = data?['displayName'] as String? ?? '';
      }

      final businessPhone = professionalControllers['businessPhone'];

      if (businessPhone != null && businessPhone.text.trim().isEmpty) {
        businessPhone.text = data?['phone'] as String? ?? '';
      }
    } catch (_) {
      // Fields remain editable if profile prefill is unavailable.
    }
  }

  Future<void> pick(String kind) async {
    if (correction != null && !correction!.documents.contains(kind)) return;
    if (busy) return;

    final navigator = Navigator.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return const SafeArea(
          child: Wrap(
            children: [
              _PhotoSourceTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                source: ImageSource.camera,
              ),
              _PhotoSourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                source: ImageSource.gallery,
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(
              builder: (_) =>
                  CameraCaptureScreen(preferFrontCamera: kind == 'selfie'),
            ),
          )
        : await ImagePicker().pickImage(
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
      final prepared = await PhotoUploadService().prepareIdentityPhoto(photo);

      if (!mounted) return;

      setState(() {
        dirty = true;
        photos[kind] = prepared;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'Choose a clear JPG or PNG photo under the supported upload size.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  List<String> get requiredDocuments {
    return [
      'nicFront',
      'nicBack',
      'selfie',
      'serviceProof',
      if (services.contains('Vehicle Towing')) 'recoveryProof',
      if (professional['providerType'] == 'business') 'businessProof',
    ];
  }

  ProviderDocumentCorrection? get correction =>
      ProviderDocumentCorrection.active(widget.application, widget.moderation);

  Future<void> submitDocumentCorrections() async {
    final request = correction;
    if (request == null || busy || submittedThisSession) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ProviderVerificationService().submitCorrections(
        revision: request.revision,
        replacements: {
          for (final key in request.documents) key: photos[key] ?? '',
        },
      );
      if (mounted)
        setState(() {
          submittedThisSession = true;
          dirty = false;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Upload a new photo for every requested document. If the request has changed, refresh and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didUpdateWidget(covariant ProviderVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRequest = oldWidget.moderation?['correctionRequest'];
    final newRequest = widget.moderation?['correctionRequest'];
    if (oldWidget.application?['revision'] != widget.application?['revision'] ||
        (oldRequest is Map ? oldRequest['requestedAt'] : null) !=
            (newRequest is Map ? newRequest['requestedAt'] : null)) {
      submittedThisSession = false;
      photos
        ..clear()
        ..addAll(
          Map<String, String>.from(
            widget.application?['documents'] as Map? ?? {},
          ),
        );
      error = null;
      dirty = false;
    }
  }

  Future<void> submit() async {
    services.addAll(customServices.map((item) => item['category']!));
    FocusScope.of(context).unfocus();

    if (busy ||
        submittedThisSession ||
        !(form.currentState?.validate() ?? false)) {
      return;
    }

    final missingDocuments = requiredDocuments.where((key) {
      final value = photos[key];

      return value == null || value.trim().isEmpty;
    }).toList();

    if (!consent ||
        services.isEmpty ||
        vehicleTypes.isEmpty ||
        missingDocuments.isNotEmpty) {
      setState(() {
        error =
            'Select services and supported vehicles, upload every required document and accept the declaration.';
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
            entry.key:
                [
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
        'businessName': professional['providerType'] == 'business'
            ? business.text.trim()
            : '',
        'emergencyPhone': emergency.text.trim().isEmpty
            ? ''
            : normalizeSriLankaPhone(emergency.text),
        'experienceYears': int.parse(experience.text.trim()),
        'services': services.toList(),
        'customServices': customServices,
        'vehicleTypes': vehicleTypes.toList(),
        'documents': photos,
      });

      if (!mounted) return;

      setState(() {
        submittedThisSession = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification application submitted for review.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not submit the application. Verify your email, check your connection and confirm that the application is editable.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  bool get changesRequested {
    if (correction != null) return true;
    if (widget.moderation?['correctionRequest'] is Map) return false;
    final application = widget.application;

    final moderation = widget.moderation;

    if (application == null || moderation?['verification'] != 'pending') {
      return false;
    }

    final moderationUpdated = (moderation?['updatedAt'] as Timestamp?)
        ?.toDate();

    final submitted = (application['submittedAt'] as Timestamp?)?.toDate();

    if (moderationUpdated == null || submitted == null) {
      return false;
    }

    return moderationUpdated.isAfter(submitted);
  }

  bool get withdrawn => widget.application?['applicationStatus'] == 'withdrawn';

  bool get canEdit {
    final application = widget.application;

    return !submittedThisSession &&
        (application == null ||
            application['professionalDetails'] is! Map ||
            changesRequested ||
            (withdrawn && applyAgain));
  }

  String get verificationStatus {
    if (withdrawn) return 'withdrawn';
    return widget.moderation?['verification'] as String? ?? 'pending';
  }

  RaTone get verificationTone {
    return switch (verificationStatus) {
      'verified' => RaTone.success,
      'rejected' => RaTone.danger,
      'pending' => RaTone.warning,
      _ => RaTone.info,
    };
  }

  String get statusTitle {
    if (withdrawn) return 'Application withdrawn';
    if (submittedThisSession) {
      return 'Application submitted';
    }

    if (widget.application == null) {
      return 'Become a verified provider';
    }

    if (changesRequested) {
      return 'Changes requested';
    }

    return switch (verificationStatus) {
      'verified' => 'Provider verified',
      'rejected' => 'Application needs attention',
      _ => 'Application under review',
    };
  }

  String get statusMessage {
    if (withdrawn)
      return 'Review has stopped. You can continue as a driver or apply again using your saved documents.';
    if (submittedThisSession) {
      return 'Your documents have been submitted for manual review.';
    }

    final reason = widget.moderation?['reason'] as String?;

    if (reason != null && reason.trim().isNotEmpty) {
      return reason;
    }

    if (widget.application == null) {
      return 'Complete your identity and service details to unlock provider jobs after manual approval.';
    }

    if (verificationStatus == 'verified') {
      return 'Your RoadAssist provider verification is currently approved.';
    }

    if (verificationStatus == 'rejected') {
      return 'Review the feedback and contact RoadAssist support if you need assistance.';
    }

    return 'Your submitted documents are waiting for manual review.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final emailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified == true;

    final validUntil = (widget.moderation?['validUntil'] as Timestamp?)
        ?.toDate()
        .toLocal();

    final approvalExpired =
        verificationStatus == 'verified' &&
        (validUntil == null || !validUntil.isAfter(DateTime.now()));

    return RaProviderScaffold(
      preventLeave: busy || (dirty && canEdit),
      leaveMessage: busy
          ? 'Please wait until your document upload or application update finishes.'
          : 'You have unsaved application changes. Leave without saving?',
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Provider Verification',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _WelcomeThemeToggle(),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy
                ? null
                : () async {
                    if (!await _confirmProviderSignOut(context)) return;
                    if (!context.mounted) return;
                    await AuthService().signOut();

                    if (!context.mounted) {
                      return;
                    }

                    replace(context, const WelcomeScreen());
                  },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _RaProviderVerificationHero(
            title: statusTitle,
            message: statusMessage,
            status: verificationStatus,
            tone: verificationTone,
          ),

          if (!emailVerified) ...[
            const SizedBox(height: 12),

            _RaProviderVerificationNotice(
              icon: Icons.mark_email_unread_outlined,
              title: 'Email verification required',
              message:
                  'Verify the email address on this account before submitting provider documents.',
              tone: colors.primary,
              actionLabel: 'Verify Email',
              onAction: () {
                push(context, const EmailVerificationScreen(role: 'provider'));
              },
            ),
          ],

          if (approvalExpired) ...[
            const SizedBox(height: 12),

            const _RaProviderVerificationNotice(
              icon: Icons.event_busy_outlined,
              title: 'Verification renewal required',
              message:
                  'The provider approval has expired or requires renewal. Contact RoadAssist support for another document review.',
              tone: raGold,
            ),
          ],

          if (validUntil != null &&
              verificationStatus == 'verified' &&
              !approvalExpired) ...[
            const SizedBox(height: 12),

            _RaProviderVerificationNotice(
              icon: Icons.verified_user_outlined,
              title: 'Verification valid',
              message:
                  'Current approval is valid until ${validUntil.day.toString().padLeft(2, '0')}/${validUntil.month.toString().padLeft(2, '0')}/${validUntil.year}.',
              tone: raSuccess,
            ),
          ],

          if (widget.application != null) ...[
            const SizedBox(height: 20),

            _RaProviderVerificationStatusCard(
              status: verificationStatus,
              tone: verificationTone,
              reason: statusMessage,
              editable: canEdit,
            ),
          ],

          if (canEdit && correction != null) ...[
            const SizedBox(height: 20),
            RaProviderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update requested documents',
                    style: _providerText(
                      context,
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.moderation?['reason']?.toString() ?? '',
                    style: _providerText(context),
                  ),
                  const SizedBox(height: 12),
                  const InlineMessage(
                    icon: Icons.lock_outline_rounded,
                    text:
                        'Your other documents and application details stay saved. Replace every document listed below.',
                  ),
                  const SizedBox(height: 12),
                  for (final key in correction!.documents) ...[
                    _RaProviderVerificationDocumentCard(
                      title: documents[key] ?? key,
                      required: true,
                      data: photos[key],
                      busy: busy,
                      onTap: () => pick(key),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (error != null)
                    InlineMessage(icon: Icons.error_outline, text: error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy || !emailVerified
                        ? null
                        : submitDocumentCorrections,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      busy ? 'Submitting...' : 'Resubmit requested documents',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canEdit && correction == null) ...[
            const SizedBox(height: 25),

            const _RaProviderVerificationSection(
              icon: Icons.badge_outlined,
              title: 'Identity details',
              subtitle:
                  'Enter details exactly as they appear on your official documents.',
            ),

            const SizedBox(height: 10),

            Form(
              onChanged: () {
                if (!dirty) setState(() => dirty = true);
              },
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RaProviderVerificationSurface(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: name,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name as shown on NIC',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'Required';
                            }

                            if (text.length < 2) {
                              return 'Enter a valid name';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: nic,
                          maxLength: 12,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'NIC number',
                            prefixIcon: Icon(Icons.fingerprint_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'Required';
                            }

                            if (!RegExp(
                              r'^(\d{9}[VXvx]|\d{12})$',
                            ).hasMatch(text)) {
                              return 'Enter a valid NIC format';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: address,
                          maxLength: 300,
                          minLines: 2,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Residential / business address',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          validator: (value) {
                            return (value?.trim().isEmpty ?? true)
                                ? 'Required'
                                : null;
                          },
                        ),

                        if (professional['providerType'] == 'business') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: business,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Business name',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (value) {
                              return (value?.trim().isEmpty ?? true)
                                  ? 'Required'
                                  : null;
                            },
                          ),
                        ],

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: emergency,
                          maxLength: 16,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Emergency contact phone (optional)',
                            prefixIcon: Icon(Icons.contact_phone_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return null;
                            }

                            return validateSriLankaPhone(text);
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: experience,
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Years of service experience',
                            prefixIcon: Icon(Icons.workspace_premium_outlined),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');

                            if (parsed == null) {
                              return 'Required';
                            }

                            if (parsed < 0 || parsed > 60) {
                              return 'Enter 0 to 60';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const _RaProviderVerificationSection(
                    icon: Icons.engineering_outlined,
                    title: 'Professional details',
                    subtitle:
                        'Describe your service capability, working pattern and professional setup.',
                  ),

                  const SizedBox(height: 10),

                  _RaProviderVerificationSurface(
                    child: _ProviderProfessionalFields(
                      controllers: professionalControllers,
                      details: professional,
                      onChanged: () {
                        setState(() {});
                      },
                      towing: services.contains('Vehicle Towing'),
                      busy: busy,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const _RaProviderVerificationSection(
                    icon: Icons.home_repair_service_outlined,
                    title: 'Services',
                    subtitle:
                        'Select every roadside service you are qualified and equipped to provide.',
                  ),

                  const SizedBox(height: 10),

                  _RaProviderVerificationSurface(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in serviceOptions)
                          FilterChip(
                            label: Text(value),
                            selected: services.contains(value),
                            onSelected: busy
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        services.add(value);
                                      } else {
                                        if (!customServices.any(
                                          (item) => item['category'] == value,
                                        ))
                                          services.remove(value);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  _ProviderAdditionalServices(
                    values: customServices,
                    onChanged: busy
                        ? null
                        : () => setState(() {
                            services.addAll(
                              customServices.map((item) => item['category']!),
                            );
                          }),
                  ),
                  const SizedBox(height: 25),
                  const _RaProviderVerificationSection(
                    icon: Icons.directions_car_outlined,
                    title: 'Supported vehicles',
                    subtitle:
                        'Choose the vehicle categories you can safely service.',
                  ),

                  const SizedBox(height: 10),

                  _RaProviderVerificationSurface(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in vehicleOptions)
                          FilterChip(
                            label: Text(value),
                            selected: vehicleTypes.contains(value),
                            onSelected: busy
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        vehicleTypes.add(value);
                                      } else {
                                        vehicleTypes.remove(value);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const _RaProviderVerificationSection(
                    icon: Icons.folder_shared_outlined,
                    title: 'Verification documents',
                    subtitle:
                        'Documents remain private and are used only for provider verification.',
                  ),

                  const SizedBox(height: 10),

                  _RaProviderVerificationNotice(
                    icon: Icons.lock_outline_rounded,
                    title: 'Private documents',
                    message:
                        'Identity and professional evidence are never displayed to drivers.',
                    tone: colors.primary,
                  ),

                  const SizedBox(height: 10),

                  const InlineMessage(
                    icon: Icons.face_outlined,
                    text:
                        'Provider selfie: upload a recent, clear photo showing your whole face in good lighting, without a mask or sunglasses. Use the front camera or choose a photo. Only authorized reviewers can view it alongside your NIC.',
                  ),
                  const SizedBox(height: 10),
                  for (final entry in documents.entries.where((entry) {
                    if (entry.key == 'businessProof' &&
                        professional['providerType'] != 'business') {
                      return false;
                    }

                    if (entry.key == 'recoveryProof' &&
                        !services.contains('Vehicle Towing')) {
                      return false;
                    }

                    return true;
                  })) ...[
                    _RaProviderVerificationDocumentCard(
                      title: entry.value,
                      required: requiredDocuments.contains(entry.key),
                      data: photos[entry.key],
                      busy: busy,
                      onTap: () {
                        pick(entry.key);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 17),

                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .25,
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: consent,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.all(11),
                        onChanged: busy
                            ? null
                            : (value) {
                                setState(() {
                                  consent = value ?? false;
                                });
                              },
                        title: Text(
                          'Provider declaration',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'I confirm that these documents are mine, the information is accurate and I will request driver approval before additional work or charges.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 12),

                    _RaProviderVerificationNotice(
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to continue',
                      message: error!,
                      tone: colors.error,
                    ),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy || !emailVerified ? null : submit,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(
                        busy
                            ? 'Submitting...'
                            : changesRequested
                            ? 'Submit Updated Application'
                            : 'Submit for Verification',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!canEdit &&
              !submittedThisSession &&
              widget.application != null) ...[
            const SizedBox(height: 16),

            _RaProviderVerificationNotice(
              icon: Icons.lock_clock_outlined,
              title: 'Documents locked',
              message:
                  'The application cannot be edited while it is under review unless a reviewer requests changes.',
              tone: colors.primary,
            ),
          ],

          if (error != null && !canEdit) ...[
            const SizedBox(height: 12),
            InlineMessage(icon: Icons.error_outline, text: error!),
          ],
          if (emailVerified &&
              verificationStatus != 'verified' &&
              verificationStatus != 'rejected') ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await ProviderVerificationService().continueAsDriver();
                        if (context.mounted)
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => AuthService.independentRoleAuth
                                  ? const LoginScreen(isProvider: false)
                                  : const DriverShell(),
                            ),
                            (_) => false,
                          );
                      } catch (_) {
                        if (mounted)
                          setState(() {
                            busy = false;
                            error =
                                'Unable to switch to driver. Please try again.';
                          });
                      }
                    },
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Continue as Driver'),
            ),
            if (withdrawn && !applyAgain)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        applyAgain = true;
                        submittedThisSession = false;
                        consent = false;
                      }),
                icon: const Icon(Icons.refresh),
                label: const Text('Apply Again'),
              ),
            if (!withdrawn &&
                (widget.application != null || submittedThisSession))
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Withdraw provider application?'),
                            content: const Text(
                              'Admin review will stop. Your account and saved documents remain available, and you can apply again later.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Keep Application'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Withdraw Application'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        setState(() => busy = true);
                        try {
                          await ProviderVerificationService().withdraw();
                          if (mounted)
                            setState(() {
                              busy = false;
                              submittedThisSession = false;
                            });
                        } catch (_) {
                          if (mounted)
                            setState(() {
                              busy = false;
                              error =
                                  'Unable to withdraw. The review may have changed; refresh and try again.';
                            });
                        }
                      },
                child: const Text('Withdraw Application'),
              ),
          ],
          const SizedBox(height: 22),

          OutlinedButton.icon(
            onPressed: () {
              push(context, const SupportScreen(isProvider: true));
            },
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Contact RoadAssist Support'),
          ),
        ],
      ),
    );
  }
}

class _RaProviderVerificationHero extends StatelessWidget {
  const _RaProviderVerificationHero({
    required this.title,
    required this.message,
    required this.status,
    required this.tone,
  });

  final String title;
  final String message;
  final String status;
  final RaTone tone;

  @override
  Widget build(BuildContext context) {
    return RaProviderSummaryCard(
      title: title,
      message: message,
      icon: Icons.verified_user_outlined,
      status: StatusPill(
        label: status.replaceAll('_', ' ').toUpperCase(),
        tone: tone,
      ),
      footer: Text(
        'Verification is a manual review of identity and service capability. Approval is not a guarantee of service quality.',
        style: _providerText(context, size: 12, muted: true),
      ),
    );
  }
}

class _RaProviderVerificationSection extends StatelessWidget {
  const _RaProviderVerificationSection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .075),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaProviderVerificationSurface extends StatelessWidget {
  const _RaProviderVerificationSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: child,
    );
  }
}

class _RaProviderVerificationNotice extends StatelessWidget {
  const _RaProviderVerificationNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 7),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderVerificationStatusCard extends StatelessWidget {
  const _RaProviderVerificationStatusCard({
    required this.status,
    required this.tone,
    required this.reason,
    required this.editable,
  });

  final String status;
  final RaTone tone;
  final String reason;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return _RaProviderVerificationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: status.replaceAll('_', ' ').toUpperCase(),
                tone: tone,
              ),
              const Spacer(),
              Icon(
                editable ? Icons.edit_outlined : Icons.lock_outline_rounded,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            reason,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.5),
          ),
          if (!editable) ...[
            const SizedBox(height: 6),
            Text(
              'Documents are locked while the current review is active.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RaProviderVerificationDocumentCard extends StatelessWidget {
  const _RaProviderVerificationDocumentCard({
    required this.title,
    required this.required,
    required this.data,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final bool required;
  final String? data;
  final bool busy;
  final VoidCallback onTap;

  Widget _preview(BuildContext context) {
    final value = data;

    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final clean = value.contains(',') ? value.split(',').last : value;

      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.memory(
          base64Decode(clean),
          height: 125,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final uploaded = data != null && data!.trim().isNotEmpty;

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: (uploaded ? raSuccess : colors.primary).withValues(
                        alpha: .08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      uploaded
                          ? Icons.check_circle_outline_rounded
                          : Icons.upload_file_outlined,
                      color: uploaded ? raSuccess : colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          required ? 'Required' : 'Optional',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: required
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    uploaded
                        ? Icons.edit_outlined
                        : Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                ],
              ),
              if (uploaded) ...[const SizedBox(height: 11), _preview(context)],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderAdditionalServices extends StatelessWidget {
  const _ProviderAdditionalServices({
    required this.values,
    required this.onChanged,
  });
  final List<Map<String, String>> values;
  final VoidCallback? onChanged;

  Future<void> add(BuildContext context) async {
    final form = GlobalKey<FormState>();
    var name = '';
    var description = '';
    var category = 'General Mechanic';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add another service'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Service name',
                    hintText: 'Fuel delivery / Vehicle lockout',
                  ),
                  maxLength: 60,
                  onChanged: (value) => name = value.trim(),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 3) return 'Enter at least 3 characters';
                    if (values.any(
                      (item) =>
                          item['name']!.toLowerCase() == text.toLowerCase(),
                    ))
                      return 'This service is already added';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Request matching category',
                  ),
                  items: [
                    for (final item
                        in _ProviderVerificationScreenState.serviceOptions)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => category = value ?? category,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'What can you provide?',
                  ),
                  maxLength: 160,
                  maxLines: 3,
                  onChanged: (value) => description = value.trim(),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Describe the service in at least 10 characters'
                      : null,
                ),
                const Text(
                  'This service is reviewed with your application and matches requests using the selected category.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() == true)
                Navigator.pop(dialogContext, {
                  'name': name,
                  'description': description,
                  'category': category,
                });
            },
            child: const Text('Add Service'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted && onChanged != null) {
      values.add(result);
      onChanged!();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Additional services / Other',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Examples: Fuel delivery, Vehicle lockout, Auto electrical, Engine overheating. Add up to 5 services you can safely provide.',
      ),
      for (final item in values)
        Card(
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(item['name']!),
              subtitle: Text(
                '${item['category']} Ãƒâ€šÃ‚Â· ${item['description']}',
              ),
              trailing: IconButton(
                tooltip: 'Remove service',
                onPressed: onChanged == null
                    ? null
                    : () {
                        values.remove(item);
                        onChanged!();
                      },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: onChanged == null || values.length >= 5
            ? null
            : () => add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Other Service'),
      ),
    ],
  );
}
