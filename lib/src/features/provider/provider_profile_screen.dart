part of '../../screens.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool accepting = true;

  String workingHours = 'Mon - Fri, 08:00 AM - 06:00 PM';

  String serviceRadius = '15 km from current location';

  String providerName = 'Service Provider';

  String providerPhone = '';

  List<String> services = const [
    'Vehicle Towing',
    'Battery Jumpstart',
    'Flat Tyre',
    'General Mechanic',
  ];

  String? photoData;

  bool uploadingPhoto = false;
  bool profileLoaded = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;

  @override
  void initState() {
    super.initState();

    if (signedIn) {
      profileSubscription = AuthService().watchCurrentProfile().listen((
        snapshot,
      ) {
        final data = snapshot.data();

        if (!mounted || data == null) {
          return;
        }

        setState(() {
          providerName = data['displayName'] as String? ?? providerName;

          providerPhone = data['phone'] as String? ?? providerPhone;

          photoData = data['photoData'] as String?;

          accepting = data['online'] as bool? ?? accepting;

          workingHours = data['workingHours'] as String? ?? workingHours;

          serviceRadius = data['serviceRadius'] as String? ?? serviceRadius;

          final savedServices = data['services'] as List<dynamic>?;

          if (savedServices != null && savedServices.isNotEmpty) {
            services = savedServices.whereType<String>().toList();
          }

          profileLoaded = true;
        });
      });
    } else {
      profileLoaded = true;
    }
  }

  @override
  void dispose() {
    profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> changeProviderPhoto() async {
    final navigator = Navigator.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.lg,
              0,
              RaSpace.lg,
              RaSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
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
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 1200,
          );

    if (photo == null || !mounted) {
      return;
    }

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

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + RaSpace.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit provider profile',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: RaSpace.lg),

                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Business / provider name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    return (value?.trim().length ?? 0) < 2
                        ? 'Enter a valid provider name'
                        : null;
                  },
                ),

                const SizedBox(height: RaSpace.md),

                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: validateSriLankaPhone,
                ),

                const SizedBox(height: RaSpace.lg),

                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(sheetContext, true);
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Profile'),
                ),
              ],
            ),
          ),
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

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone number are required.')),
      );
      return;
    }

    await AuthService().updateCurrentProfile({
      'displayName': name,
      'phone': phone,
    });

    await AuthService().syncProviderDirectory();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Provider profile updated.')));
  }

  Future<void> editSettings() async {
    var hours = workingHours;
    var radius = serviceRadius;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.lg,
                  0,
                  RaSpace.lg,
                  RaSpace.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Availability settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: RaSpace.lg),

                    DropdownButtonFormField<String>(
                      initialValue: hours,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Working hours',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Mon - Fri, 08:00 AM - 06:00 PM',
                          child: Text('Weekdays · 8 AM–6 PM'),
                        ),
                        DropdownMenuItem(
                          value: 'Daily, 08:00 AM - 08:00 PM',
                          child: Text('Daily · 8 AM–8 PM'),
                        ),
                        DropdownMenuItem(
                          value: '24 hours, 7 days a week',
                          child: Text('24 hours · Every day'),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          hours = value ?? hours;
                        });
                      },
                    ),

                    const SizedBox(height: RaSpace.md),

                    DropdownButtonFormField<String>(
                      initialValue: radius,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Service radius',
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
                        setSheetState(() {
                          radius = value ?? radius;
                        });
                      },
                    ),

                    const SizedBox(height: RaSpace.lg),

                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    if (signedIn) {
      await AuthService().updateCurrentProfile({
        'workingHours': hours,
        'serviceRadius': radius,
      });

      await AuthService().syncProviderDirectory();
    }

    if (!mounted) return;

    setState(() {
      workingHours = hours;
      serviceRadius = radius;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Availability settings updated.')),
    );
  }

  Future<void> editServices() async {
    const availableServices = [
      'Vehicle Towing',
      'Battery Jumpstart',
      'Flat Tyre',
      'General Mechanic',
    ];

    final selected = services.toSet();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.lg,
                0,
                RaSpace.lg,
                RaSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Services offered',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: RaSpace.md),

                  for (final service in availableServices)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(serviceIcon(service)),
                      title: Text(service),
                      value: selected.contains(service),
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            selected.add(service);
                          } else {
                            selected.remove(service);
                          }
                        });
                      },
                    ),

                  const SizedBox(height: RaSpace.md),

                  FilledButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save Services'),
                  ),
                ],
              ),
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

  IconData serviceIcon(String service) {
    return switch (service) {
      'Vehicle Towing' => Icons.fire_truck_outlined,
      'Battery Jumpstart' => Icons.battery_charging_full,
      'Flat Tyre' => Icons.tire_repair,
      _ => Icons.car_repair,
    };
  }

  Widget _profileImage(String name) {
    if (photoData == null || photoData!.isEmpty) {
      return ProfileInitials(name: name, radius: 44);
    }

    try {
      return CircleAvatar(
        radius: 44,
        backgroundImage: MemoryImage(base64Decode(photoData!)),
      );
    } on FormatException {
      return ProfileInitials(name: name, radius: 44);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Provider Profile'),
        actions: [
          IconButton(
            tooltip: 'Availability settings',
            onPressed: editSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: RaSpace.sm),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          if (!profileLoaded) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: RaSpace.md),
          ],

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firebaseReady ? AuthService().watchCurrentProfile() : null,
            builder: (context, snapshot) {
              final data = snapshot.data?.data();

              final name =
                  data?['displayName'] as String? ??
                  (firebaseReady
                      ? FirebaseAuth.instance.currentUser?.displayName
                      : null) ??
                  'Service Provider';

              final phone = data?['phone'] as String? ?? 'Phone not added';

              final email =
                  data?['email'] as String? ??
                  (firebaseReady
                      ? FirebaseAuth.instance.currentUser?.email
                      : null) ??
                  '';

              return Container(
                padding: const EdgeInsets.all(RaSpace.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, const Color(0xFF007D70)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _profileImage(name),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: IconButton.filled(
                            tooltip: 'Change provider photo',
                            onPressed: uploadingPhoto
                                ? null
                                : changeProviderPhoto,
                            icon: uploadingPhoto
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: RaSpace.md),

                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .80),
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: RaSpace.sm,
                      runSpacing: RaSpace.sm,
                      children: [
                        _ProviderProfileHeroChip(
                          icon: Icons.verified_outlined,
                          label: 'RoadAssist Provider',
                        ),
                        _ProviderProfileHeroChip(
                          icon: Icons.phone_outlined,
                          label: phone,
                        ),
                      ],
                    ),

                    const SizedBox(height: RaSpace.lg),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .45),
                          ),
                        ),
                        onPressed: editProviderProfile,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Provider Profile'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: RaSpace.xxl),

          Text(
            'Driver ratings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: RaSpace.md),

          const _ProviderRatingSummary(),

          const SizedBox(height: RaSpace.xxl),

          Container(
            padding: const EdgeInsets.all(RaSpace.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .6),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accepting
                        ? raSuccess.withValues(alpha: .10)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    accepting
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    color: accepting ? raSuccess : colors.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  'Accepting Requests',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  accepting
                      ? 'You are currently online'
                      : 'You are currently offline',
                ),
                value: accepting,
                onChanged: (value) async {
                  final previous = accepting;

                  setState(() {
                    accepting = value;
                  });

                  try {
                    if (firebaseReady) {
                      await AuthService().setProviderOnline(value);
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        accepting = previous;
                      });
                    }
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: RaSpace.xxl),

          _ProviderProfileSection(
            title: 'Availability',
            action: 'Edit',
            onAction: editSettings,
            children: [
              _ProviderProfileRow(
                icon: Icons.schedule_outlined,
                title: 'Working Hours',
                value: workingHours,
              ),
              _ProviderProfileRow(
                icon: Icons.radar_outlined,
                title: 'Service Radius',
                value: serviceRadius,
              ),
            ],
          ),

          const SizedBox(height: RaSpace.xxl),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Services offered',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: editServices,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit'),
              ),
            ],
          ),

          const SizedBox(height: RaSpace.md),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: RaSpace.sm,
              mainAxisSpacing: RaSpace.sm,
              mainAxisExtent: 112,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];

              return Container(
                padding: const EdgeInsets.all(RaSpace.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        serviceIcon(service),
                        color: colors.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      service,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: RaSpace.xxl),

          _ProviderProfileMenuGroup(
            children: [
              _ProviderProfileMenuTile(
                icon: Icons.security_outlined,
                title: 'Account & Security',
                subtitle: 'Password, verification and account settings',
                onTap: () => push(context, const AccountSecurityScreen()),
              ),
              _ProviderProfileMenuTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Background alerts and device permissions',
                onTap: () => push(context, const NotificationSettingsScreen()),
              ),
              _ProviderProfileMenuTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Light, dark or system theme',
                onTap: () => push(context, const AppearanceScreen()),
              ),
              _ProviderProfileMenuTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Support, safety and troubleshooting',
                onTap: () =>
                    push(context, const SupportScreen(isProvider: true)),
              ),
              _ProviderProfileMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & Safety',
                subtitle: 'Review privacy and safety controls',
                onTap: () =>
                    push(context, const PrivacySafetyScreen(isProvider: true)),
              ),
            ],
          ),

          const SizedBox(height: RaSpace.xl),

          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();

              if (context.mounted) {
                replace(context, const WelcomeScreen());
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: .55)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProviderProfileHeroChip extends StatelessWidget {
  const _ProviderProfileHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderProfileSection extends StatelessWidget {
  const _ProviderProfileSection({
    required this.title,
    required this.children,
    this.action,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
        const SizedBox(height: RaSpace.md),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .6),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ProviderProfileRow extends StatelessWidget {
  const _ProviderProfileRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RaSpace.md,
          vertical: 4,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(value),
      ),
    );
  }
}

class _ProviderProfileMenuGroup extends StatelessWidget {
  const _ProviderProfileMenuGroup({required this.children});

  final List<_ProviderProfileMenuTile> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProviderProfileMenuTile extends StatelessWidget {
  const _ProviderProfileMenuTile({
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
    final colors = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RaSpace.md,
          vertical: 5,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
