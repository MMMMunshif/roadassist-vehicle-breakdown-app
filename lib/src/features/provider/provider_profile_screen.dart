part of '../../screens.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState
    extends State<ProviderProfileScreen> {
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

    profileSubscription =
        AuthService().watchCurrentProfile().listen(
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
            (data['services'] as List<dynamic>? ??
                    const [])
                .whereType<String>()
                .where(
                  (service) =>
                      service.trim().isNotEmpty,
                )
                .toList();

        setState(() {
          providerName =
              data['displayName'] as String? ??
                  providerName;

          providerPhone =
              data['phone'] as String? ??
                  providerPhone;

          photoData =
              data['photoData'] as String?;

          accepting =
              data['online'] == true;

          workingHours =
              data['workingHours'] as String? ??
                  '';

          serviceRadius =
              data['serviceRadius'] as String? ??
                  '';

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

    final source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return const SafeArea(
          child: Wrap(
            children: [
              _PhotoSourceTile(
                icon:
                    Icons.photo_library_outlined,
                label: 'Choose from gallery',
                source: ImageSource.gallery,
              ),
              _PhotoSourceTile(
                icon:
                    Icons.camera_alt_outlined,
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
            MaterialPageRoute(
              builder: (_) =>
                  const CameraCaptureScreen(),
            ),
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
      final encoded =
          await PhotoUploadService()
              .prepareProfilePhoto(photo);

      await AuthService().updateCurrentProfile({
        'photoData': encoded,
      });

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      setState(() {
        photoData = encoded;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provider photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo update failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> editProviderProfile() async {
    final formKey =
        GlobalKey<FormState>();

    final nameController =
        TextEditingController(
      text: providerName,
    );

    final phoneController =
        TextEditingController(
      text: providerPhone,
    );

    final saved =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.person_outline_rounded,
          ),
          title: const Text(
            'Edit Provider Profile',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization:
                      TextCapitalization.words,
                  maxLength: 100,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Business / provider name',
                    prefixIcon: Icon(
                      Icons.business_outlined,
                    ),
                  ),
                  validator: (value) {
                    final name =
                        value?.trim() ?? '';

                    if (name.length < 2) {
                      return 'Enter a valid provider name';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  keyboardType:
                      TextInputType.phone,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Phone number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                  ),
                  validator:
                      validateSriLankaPhone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState
                        ?.validate() ??
                    false) {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
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

    final name =
        nameController.text.trim();

    final phone =
        normalizeSriLankaPhone(
      phoneController.text,
    );

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
        const SnackBar(
          content: Text(
            'Provider profile updated.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update provider profile.',
          ),
        ),
      );
    }
  }

  Future<void> editSettings() async {
    String? selectedHours =
        workingHourOptions.contains(
          workingHours,
        )
            ? workingHours
            : null;

    String? selectedRadius =
        serviceRadiusOptions.contains(
          serviceRadius,
        )
            ? serviceRadius
            : null;

    final saved =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              icon: const Icon(
                Icons.schedule_outlined,
              ),
              title: const Text(
                'Availability Settings',
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  DropdownButtonFormField<
                      String>(
                    initialValue:
                        selectedHours,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Working Hours',
                      prefixIcon: Icon(
                        Icons
                            .schedule_outlined,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value:
                            'Mon - Fri, 08:00 AM - 06:00 PM',
                        child: Text(
                          'Weekdays · 8 AM–6 PM',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'Daily, 08:00 AM - 08:00 PM',
                        child: Text(
                          'Daily · 8 AM–8 PM',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            '24 hours, 7 days a week',
                        child: Text(
                          '24 hours · Every day',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedHours = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<
                      String>(
                    initialValue:
                        selectedRadius,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Service Radius',
                      prefixIcon: Icon(
                        Icons.radar_outlined,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value:
                            '5 km from current location',
                        child: Text('5 km'),
                      ),
                      DropdownMenuItem(
                        value:
                            '15 km from current location',
                        child: Text('15 km'),
                      ),
                      DropdownMenuItem(
                        value:
                            '30 km from current location',
                        child: Text('30 km'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRadius =
                            value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      selectedHours == null ||
                              selectedRadius ==
                                  null
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                                true,
                              );
                            },
                  child:
                      const Text('Save Settings'),
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
        const SnackBar(
          content: Text(
            'Availability settings updated.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update availability settings.',
          ),
        ),
      );
    }
  }

  Future<void> editServices() async {
    final selected =
        services.toSet();

    final saved =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              icon: const Icon(
                Icons
                    .home_repair_service_outlined,
              ),
              title: const Text(
                'Services Offered',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    for (final service
                        in availableServices)
                      CheckboxListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        controlAffinity:
                            ListTileControlAffinity
                                .trailing,
                        title: Text(service),
                        value: selected
                            .contains(service),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked ==
                                true) {
                              selected.add(
                                service,
                              );
                            } else {
                              selected.remove(
                                service,
                              );
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        },
                  child:
                      const Text('Save Services'),
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

    final updated =
        availableServices
            .where(selected.contains)
            .toList();

    try {
      await AuthService().updateCurrentProfile({
        'services': updated,
      });

      await AuthService().syncProviderDirectory();

      if (!mounted) return;

      setState(() {
        services = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Services updated successfully.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update services.',
          ),
        ),
      );
    }
  }

  Future<void> changeAvailability(
    bool value,
  ) async {
    if (changingAvailability) return;

    final previous =
        accepting;

    setState(() {
      accepting = value;
      changingAvailability = true;
    });

    try {
      await AuthService().setProviderOnline(
        value,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        accepting = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update availability.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          changingAvailability =
              false;
        });
      }
    }
  }

  IconData serviceIcon(
    String service,
  ) {
    return switch (service) {
      'Vehicle Towing' =>
        Icons.fire_truck_outlined,
      'Battery Jumpstart' =>
        Icons.battery_charging_full_rounded,
      'Flat Tyre' =>
        Icons.tire_repair_outlined,
      'General Mechanic' =>
        Icons.car_repair_outlined,
      _ =>
        Icons.home_repair_service_outlined,
    };
  }

  Widget _profileAvatar(
    String name,
  ) {
    final value =
        photoData;

    if (value == null ||
        value.trim().isEmpty) {
      return ProfileInitials(
        name: name,
        radius: 41,
      );
    }

    try {
      final clean = value.contains(',')
          ? value.split(',').last
          : value;

      return CircleAvatar(
        radius: 41,
        backgroundImage: MemoryImage(
          base64Decode(clean),
        ),
      );
    } catch (_) {
      return ProfileInitials(
        name: name,
        radius: 41,
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
        automaticallyImplyLeading:
            false,
        titleSpacing: 18,
        title: Text(
          'Provider Profile',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -.45,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Availability settings',
            onPressed: profileLoaded
                ? editSettings
                : null,
            icon: const Icon(
              Icons.tune_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !signedIn
          ? const Padding(
              padding:
                  EdgeInsets.all(20),
              child: EmptyState(
                icon:
                    Icons.login_outlined,
                title:
                    'Sign in required',
                message:
                    'Sign in to manage your provider profile.',
              ),
            )
          : !profileLoaded
              ? const Center(
                  child:
                      CircularProgressIndicator(),
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
                    final data =
                        snapshot.data?.data() ??
                            <String, dynamic>{};

                    final name =
                        data['displayName']
                                as String? ??
                            providerName;

                    final phone =
                        data['phone']
                                as String? ??
                            providerPhone;

                    final email =
                        data['email']
                                as String? ??
                            FirebaseAuth.instance
                                .currentUser
                                ?.email ??
                            '';

                    final displayName =
                        name.trim().isEmpty
                            ? 'Service Provider'
                            : name;

                    return ListView(
                      physics:
                          const BouncingScrollPhysics(),
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        18,
                        8,
                        18,
                        32,
                      ),
                      children: [
                        _RaProviderProfileHero(
                          name:
                              displayName,
                          phone:
                              phone,
                          email:
                              email,
                          accepting:
                              accepting,
                          avatar:
                              _profileAvatar(
                            displayName,
                          ),
                          uploadingPhoto:
                              uploadingPhoto,
                          onPhotoTap:
                              changeProviderPhoto,
                          onEditTap:
                              editProviderProfile,
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _RaProviderAvailabilityCard(
                          accepting:
                              accepting,
                          busy:
                              changingAvailability,
                          onChanged:
                              changeAvailability,
                          workingHours:
                              workingHours,
                          serviceRadius:
                              serviceRadius,
                          onEdit:
                              editSettings,
                        ),

                        const SizedBox(
                          height: 25,
                        ),

                        const _RaProviderProfileSectionHeading(
                          title:
                              'Driver ratings',
                          subtitle:
                              'Ratings submitted after completed RoadAssist jobs.',
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const _ProviderRatingSummary(),

                        const SizedBox(
                          height: 25,
                        ),

                        _RaProviderProfileSectionHeading(
                          title:
                              'Services offered',
                          subtitle:
                              services.isEmpty
                                  ? 'No services are configured yet.'
                                  : 'These services are used when matching new driver requests.',
                          action:
                              'Edit',
                          onAction:
                              editServices,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        if (services.isEmpty)
                          const EmptyState(
                            icon: Icons
                                .home_repair_service_outlined,
                            title:
                                'No services configured',
                            message:
                                'Add at least one roadside service to receive matching requests.',
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final service
                                  in services)
                                _RaProviderProfileServiceChip(
                                  icon:
                                      serviceIcon(
                                    service,
                                  ),
                                  label:
                                      service,
                                ),
                            ],
                          ),

                        const SizedBox(
                          height: 25,
                        ),

                        const _RaProviderProfileSectionHeading(
                          title:
                              'Account',
                          subtitle:
                              'Security, appearance and RoadAssist support.',
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        _RaProviderProfileLink(
                          icon: Icons
                              .security_outlined,
                          title:
                              'Account & Security',
                          subtitle:
                              'Password, verification and account controls',
                          onTap: () {
                            push(
                              context,
                              const AccountSecurityScreen(),
                            );
                          },
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        _RaProviderProfileLink(
                          icon: Icons
                              .palette_outlined,
                          title:
                              'Appearance',
                          subtitle:
                              'Light, dark or system theme',
                          onTap: () {
                            push(
                              context,
                              const AppearanceScreen(),
                            );
                          },
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        _RaProviderProfileLink(
                          icon: Icons
                              .support_agent_outlined,
                          title:
                              'RoadAssist Support',
                          subtitle:
                              'Get help with your provider account or jobs',
                          onTap: () {
                            push(
                              context,
                              const SupportScreen(
                                isProvider:
                                    true,
                              ),
                            );
                          },
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        OutlinedButton.icon(
                          onPressed:
                              () async {
                            await AuthService()
                                .signOut();

                            if (!context
                                .mounted) {
                              return;
                            }

                            replace(
                              context,
                              const WelcomeScreen(),
                            );
                          },
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                colors.error,
                            side: BorderSide(
                              color:
                                  colors.error,
                            ),
                          ),
                          icon: const Icon(
                            Icons.logout_rounded,
                          ),
                          label:
                              const Text(
                            'Sign Out',
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _RaProviderProfileHero
    extends StatelessWidget {
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

  final String name;
  final String phone;
  final String email;
  final bool accepting;
  final Widget avatar;
  final bool uploadingPhoto;
  final VoidCallback onPhotoTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF08635D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(3),
                decoration:
                    const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: avatar,
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: IconButton.filled(
                  tooltip:
                      'Change provider photo',
                  onPressed:
                      uploadingPhoto
                          ? null
                          : onPhotoTap,
                  style:
                      IconButton.styleFrom(
                    backgroundColor:
                        Colors.white,
                    foregroundColor:
                        raBlue,
                  ),
                  icon: uploadingPhoto
                      ? const SizedBox.square(
                          dimension: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .camera_alt_outlined,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            name,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(999),
            ),
            child: Text(
              accepting
                  ? 'ACCEPTING REQUESTS'
                  : 'OFFLINE',
              style:
                  GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
          ),

          const SizedBox(height: 14),

          _RaProviderProfileHeroInfo(
            icon: Icons.phone_outlined,
            value: phone.trim().isEmpty
                ? 'Phone not added'
                : phone,
          ),

          if (email.trim().isNotEmpty)
            _RaProviderProfileHeroInfo(
              icon: Icons.email_outlined,
              value: email,
            ),

          const SizedBox(height: 11),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,
                side: BorderSide(
                  color: Colors.white
                      .withValues(
                    alpha: .45,
                  ),
                ),
              ),
              onPressed: onEditTap,
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label:
                  const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderProfileHeroInfo
    extends StatelessWidget {
  const _RaProviderProfileHeroInfo({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 8.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderAvailabilityCard
    extends StatelessWidget {
  const _RaProviderAvailabilityCard({
    required this.accepting,
    required this.busy,
    required this.onChanged,
    required this.workingHours,
    required this.serviceRadius,
    required this.onEdit,
  });

  final bool accepting;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final String workingHours;
  final String serviceRadius;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: (accepting
                          ? raSuccess
                          : colors
                              .onSurfaceVariant)
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
                  accepting
                      ? Icons
                          .wifi_tethering_rounded
                      : Icons
                          .wifi_off_rounded,
                  color: accepting
                      ? raSuccess
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
                      'Accepting Requests',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      accepting
                          ? 'Your provider account is available for matching.'
                          : 'You are not receiving new matching requests.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.3,
                        height: 1.4,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: accepting,
                onChanged:
                    busy ? null : onChanged,
              ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(
            height: 1,
            color: colors.outlineVariant
                .withValues(alpha: .35),
          ),

          const SizedBox(height: 12),

          _RaProviderAvailabilityRow(
            icon:
                Icons.schedule_outlined,
            label:
                'Working hours',
            value: workingHours
                    .trim()
                    .isEmpty
                ? 'Not configured'
                : workingHours,
          ),

          _RaProviderAvailabilityRow(
            icon: Icons.radar_outlined,
            label:
                'Service radius',
            value: serviceRadius
                    .trim()
                    .isEmpty
                ? 'Not configured'
                : serviceRadius,
          ),

          const SizedBox(height: 9),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(
                Icons.tune_rounded,
              ),
              label: const Text(
                'Edit Availability',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderAvailabilityRow
    extends StatelessWidget {
  const _RaProviderAvailabilityRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 8.8,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderProfileSectionHeading
    extends StatelessWidget {
  const _RaProviderProfileSectionHeading({
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  height: 1.4,
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (action != null &&
            onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!),
          ),
      ],
    );
  }
}

class _RaProviderProfileServiceChip
    extends StatelessWidget {
  const _RaProviderProfileServiceChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width:
          (MediaQuery.sizeOf(context).width -
                  44) /
              2,
      constraints:
          const BoxConstraints(
        minHeight: 85,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(
                0xFF0D1D2B,
              )
            : Colors.white,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 21,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 9.2,
              height: 1.3,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaProviderProfileLink
    extends StatelessWidget {
  const _RaProviderProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Material(
      color: theme.brightness ==
              Brightness.dark
          ? const Color(
              0xFF0D1D2B,
            )
          : Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        side: BorderSide(
          color: colors
              .outlineVariant
              .withValues(
            alpha: .45,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(
            13,
          ),
          child: Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration:
                    BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .07,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      colors.primary,
                  size: 20,
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
                      title,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.2,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}