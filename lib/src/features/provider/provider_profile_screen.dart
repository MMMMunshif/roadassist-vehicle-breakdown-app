part of '../../screens.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool accepting = false;
  bool profileLoaded = false;
  bool uploadingPhoto = false;
  bool changingAvailability = false;

  String workingHours = '';
  String serviceRadius = '';
  String providerName = '';
  String providerPhone = '';

  String? photoData;

  List<String> services = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;

  static const availableServices = [
    'Vehicle Towing',
    'Battery Jumpstart',
    'Flat Tyre',
    'General Mechanic',
  ];

  static const workingHourOptions = [
    'Mon - Fri, 08:00 AM - 06:00 PM',
    'Daily, 08:00 AM - 08:00 PM',
    '24 hours, 7 days a week',
  ];

  static const serviceRadiusOptions = [
    '5 km from current location',
    '15 km from current location',
    '30 km from current location',
  ];

  @override
  void initState() {
    super.initState();

    if (!signedIn) {
      profileLoaded = true;
      return;
    }

    profileSubscription = AuthService().watchCurrentProfile().listen(
      (snapshot) {
        final data = snapshot.data();

        if (!mounted) return;

        if (data == null) {
          setState(() {
            profileLoaded = true;
          });

          return;
        }

        final savedServices =
            [
                  ...(data['services'] as List<dynamic>? ?? const []),
                  ...(data['additionalServiceNames'] as List<dynamic>? ??
                      const []),
                ]
                .whereType<String>()
                .where((service) => service.trim().isNotEmpty)
                .toList();

        setState(() {
          providerName = data['displayName'] as String? ?? providerName;

          providerPhone = data['phone'] as String? ?? providerPhone;

          photoData = data['photoData'] as String?;

          accepting = data['online'] == true;

          workingHours = data['workingHours'] as String? ?? '';

          serviceRadius = data['serviceRadius'] as String? ?? '';

          services = savedServices;

          profileLoaded = true;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          profileLoaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> changeProviderPhoto() async {
    if (uploadingPhoto) return;

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
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                source: ImageSource.gallery,
              ),
              _PhotoSourceTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                source: ImageSource.camera,
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 1200,
          );

    if (photo == null || !mounted) return;

    setState(() {
      uploadingPhoto = true;
    });

    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);

      await AuthService().updateCurrentProfile({'photoData': encoded});

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      setState(() {
        photoData = encoded;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provider photo updated.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo update failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> editProviderProfile() async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: providerName);

    final phoneController = TextEditingController(text: providerPhone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.person_outline_rounded),
          title: const Text('Edit Provider Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Business / provider name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.length < 2) {
                      return 'Enter a valid provider name';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: validateSriLankaPhone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    final name = nameController.text.trim();

    final phone = normalizeSriLankaPhone(phoneController.text);

    nameController.dispose();
    phoneController.dispose();

    try {
      await AuthService().updateCurrentProfile({
        'displayName': name,
        'phone': phone,
      });

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider profile updated.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update provider profile.')),
      );
    }
  }

  Future<void> editSettings() async {
    String? selectedHours = workingHourOptions.contains(workingHours)
        ? workingHours
        : null;

    String? selectedRadius = serviceRadiusOptions.contains(serviceRadius)
        ? serviceRadius
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.schedule_outlined),
              title: const Text('Availability Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedHours,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Working Hours',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Mon - Fri, 08:00 AM - 06:00 PM',
                        child: Text('Weekdays Â· 8 AMâ€“6 PM'),
                      ),
                      DropdownMenuItem(
                        value: 'Daily, 08:00 AM - 08:00 PM',
                        child: Text('Daily Â· 8 AMâ€“8 PM'),
                      ),
                      DropdownMenuItem(
                        value: '24 hours, 7 days a week',
                        child: Text('24 hours Â· Every day'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedHours = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRadius,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Service Radius',
                      prefixIcon: Icon(Icons.radar_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '5 km from current location',
                        child: Text('5 km'),
                      ),
                      DropdownMenuItem(
                        value: '15 km from current location',
                        child: Text('15 km'),
                      ),
                      DropdownMenuItem(
                        value: '30 km from current location',
                        child: Text('30 km'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRadius = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedHours == null || selectedRadius == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true ||
        !mounted ||
        selectedHours == null ||
        selectedRadius == null) {
      return;
    }

    try {
      await AuthService().updateCurrentProfile({
        'workingHours': selectedHours,
        'serviceRadius': selectedRadius,
      });

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      setState(() {
        workingHours = selectedHours!;
        serviceRadius = selectedRadius!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability settings updated.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update availability settings.'),
        ),
      );
    }
  }

  Future<void> editServices() async {
    final selected = services.toSet();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.home_repair_service_outlined),
              title: const Text('Services Offered'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final service in availableServices)
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(service),
                          value: selected.contains(service),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(service);
                              } else {
                                selected.remove(service);
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Save Services'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    final updated = availableServices.where(selected.contains).toList();

    try {
      await AuthService().updateCurrentProfile({'services': updated});

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      setState(() {
        services = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services updated successfully.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update services.')),
      );
    }
  }

  Future<void> changeAvailability(bool value) async {
    if (changingAvailability) return;

    final previous = accepting;

    setState(() {
      accepting = value;
      changingAvailability = true;
    });

    try {
      await AuthService().setProviderOnline(value);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        accepting = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update availability.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          changingAvailability = false;
        });
      }
    }
  }

  IconData serviceIcon(String service) {
    return switch (service) {
      'Vehicle Towing' => Icons.fire_truck_outlined,
      'Battery Jumpstart' => Icons.battery_charging_full_rounded,
      'Flat Tyre' => Icons.tire_repair_outlined,
      'General Mechanic' => Icons.car_repair_outlined,
      _ => Icons.home_repair_service_outlined,
    };
  }

  Widget _profileAvatar(String name) {
    final value = photoData;

    if (value == null || value.trim().isEmpty) {
      return ProfileInitials(name: name, radius: 41);
    }

    try {
      final clean = value.contains(',') ? value.split(',').last : value;

      return CircleAvatar(
        radius: 41,
        backgroundImage: MemoryImage(base64Decode(clean)),
      );
    } catch (_) {
      return ProfileInitials(name: name, radius: 41);
    }
  }

  Future<void> _openVerification() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('providerApplications')
            .doc(uid)
            .get(),
        FirebaseFirestore.instance
            .collection('accountModeration')
            .doc(uid)
            .get(),
      ]);
      if (!mounted) return;
      push(
        context,
        ProviderVerificationScreen(
          application: results[0].data(),
          moderation: results[1].data(),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load verification documents. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RaProviderScaffold(
      body: !signedIn
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.login_outlined,
                  title: 'Sign in required',
                  message: 'Sign in to manage your provider profile.',
                ),
              ),
            )
          : !profileLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  RaProviderHeader(
                    notifications: _ProviderRequestBadge(services: services),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Provider profile',
                    style: _providerText(
                      context,
                      size: 24,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RaProviderProfileHero(
                    name: providerName.trim().isEmpty
                        ? 'Service Provider'
                        : providerName,
                    phone: providerPhone,
                    email: FirebaseAuth.instance.currentUser?.email ?? '',
                    accepting: accepting,
                    avatar: _profileAvatar(providerName),
                    uploadingPhoto: uploadingPhoto,
                    onPhotoTap: changeProviderPhoto,
                    onEditTap: editProviderProfile,
                  ),
                  const SizedBox(height: 22),
                  const RaProviderSection(title: 'Availability & coverage'),
                  const SizedBox(height: 10),
                  _RaProviderAvailabilityCard(
                    accepting: accepting,
                    busy: changingAvailability,
                    onChanged: changeAvailability,
                    workingHours: workingHours,
                    serviceRadius: serviceRadius,
                    onEdit: editSettings,
                  ),
                  const SizedBox(height: 18),
                  RaProviderSection(
                    title: 'Services offered',
                    action: 'Manage',
                    onAction: editServices,
                  ),
                  const SizedBox(height: 8),
                  if (services.isEmpty)
                    const RaProviderEmptyCard(
                      icon: Icons.home_repair_service_outlined,
                      title: 'No services configured',
                      message:
                          'Add at least one roadside service to receive matching requests.',
                    )
                  else
                    RaProviderCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (var i = 0; i < services.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            RaProviderSettingRow(
                              icon: serviceIcon(services[i]),
                              label: services[i],
                              onTap: editServices,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  const RaProviderSection(title: 'Account'),
                  const SizedBox(height: 10),
                  RaProviderCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        RaProviderSettingRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Verification documents',
                          onTap: _openVerification,
                        ),
                        const Divider(height: 1),
                        RaProviderSettingRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notification settings',
                          onTap: () =>
                              push(context, const NotificationSettingsScreen()),
                        ),
                        const Divider(height: 1),
                        RaProviderSettingRow(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & support',
                          onTap: () => push(
                            context,
                            const SupportScreen(isProvider: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Existing account tools and ratings remain available without crowding the main settings.
                  RaProviderCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        'More account options',
                        style: _providerText(context, size: 13),
                      ),
                      children: [
                        RaProviderSettingRow(
                          icon: Icons.security_outlined,
                          label: 'Account & security',
                          onTap: () =>
                              push(context, const AccountSecurityScreen()),
                        ),
                        RaProviderSettingRow(
                          icon: Icons.palette_outlined,
                          label: 'Appearance',
                          onTap: () => push(context, const AppearanceScreen()),
                        ),
                        ExpansionTile(
                          title: Text(
                            'Driver ratings',
                            style: _providerText(context, size: 13),
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: _ProviderRatingSummary(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (!await _confirmProviderSignOut(context)) return;
                      if (!context.mounted) return;
                      await AuthService().signOut();
                      if (context.mounted) {
                        replace(context, const WelcomeScreen());
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: .55),
                      ),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RaProviderProfileHero extends StatelessWidget {
  const _RaProviderProfileHero({
    required this.name,
    required this.phone,
    required this.email,
    required this.accepting,
    required this.avatar,
    required this.uploadingPhoto,
    required this.onPhotoTap,
    required this.onEditTap,
  });
  final String name, phone, email;
  final bool accepting, uploadingPhoto;
  final Widget avatar;
  final VoidCallback onPhotoTap, onEditTap;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final edit = OutlinedButton.icon(
          onPressed: onEditTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit profile'),
        );
        final stacked =
            constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tooltip(
                  message: 'Change provider photo',
                  child: InkWell(
                    onTap: uploadingPhoto ? null : onPhotoTap,
                    customBorder: const CircleBorder(),
                    child: Semantics(
                      button: true,
                      label: 'Change provider photo',
                      child: SizedBox.square(
                        dimension: 50,
                        child: uploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : FittedBox(child: avatar),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: _providerText(
                          context,
                          size: 17,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const _RaProviderVerificationBadge(),
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 8), edit],
              ],
            ),
            if (stacked) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: edit),
            ],
          ],
        );
      },
    ),
  );
}

class _RaProviderAvailabilityCard extends StatelessWidget {
  const _RaProviderAvailabilityCard({
    required this.accepting,
    required this.busy,
    required this.onChanged,
    required this.workingHours,
    required this.serviceRadius,
    required this.onEdit,
  });
  final bool accepting, busy;
  final ValueChanged<bool> onChanged;
  final String workingHours, serviceRadius;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => RaProviderCard(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        RaProviderSettingRow(
          icon: Icons.power_settings_new_rounded,
          label: 'Accepting requests',
          trailing: Semantics(
            label: 'Accepting requests',
            child: Switch(value: accepting, onChanged: busy ? null : onChanged),
          ),
        ),
        const Divider(height: 1),
        RaProviderSettingRow(
          icon: Icons.location_on_outlined,
          label: 'Service radius',
          value: serviceRadius.trim().isEmpty
              ? 'Not configured'
              : serviceRadius,
          onTap: onEdit,
        ),
        const Divider(height: 1),
        RaProviderSettingRow(
          icon: Icons.schedule_outlined,
          label: 'Working hours',
          value: workingHours.trim().isEmpty ? 'Not configured' : workingHours,
          onTap: onEdit,
        ),
      ],
    ),
  );
}

class _RaProviderVerificationBadge extends StatelessWidget {
  const _RaProviderVerificationBadge();
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerApplications')
          .doc(user.uid)
          .snapshots(),
      builder: (context, application) =>
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('accountModeration')
                .doc(user.uid)
                .snapshots(),
            builder: (context, moderation) {
              if (application.hasError || moderation.hasError) {
                return Text(
                  'Verification unavailable',
                  style: _providerText(context, size: 12, muted: true),
                );
              }
              if (!application.hasData || !moderation.hasData) {
                return Text(
                  'Checking verification…',
                  style: _providerText(context, size: 12, muted: true),
                );
              }
              final approved = const ProviderShell()._isApproved(
                user: user,
                application: application.data?.data(),
                moderation: moderation.data?.data(),
              );
              return StatusPill(
                label: approved ? 'Verified provider' : 'Not verified',
                tone: approved ? RaTone.success : RaTone.warning,
              );
            },
          ),
    );
  }
}
