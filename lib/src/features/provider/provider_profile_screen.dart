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
        if (!mounted || data == null) return;
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
      builder: (context) => SafeArea(
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
    setState(() => uploadingPhoto = true);
    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);
      await AuthService().updateCurrentProfile({'photoData': encoded});
      await AuthService().syncProviderDirectory();
      if (!mounted) return;
      setState(() => photoData = encoded);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provider photo updated.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo update failed: $error')));
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> editProviderProfile() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: providerName);
    final phoneController = TextEditingController(text: providerPhone);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Provider Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business / provider name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a valid provider name'
                    : null,
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
      ),
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider profile updated.')),
      );
  }

  Future<void> editSettings() async {
    var hours = workingHours;
    var radius = serviceRadius;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Availability Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: hours,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Working Hours'),
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
                onChanged: (value) =>
                    setDialogState(() => hours = value ?? hours),
              ),
              const SizedBox(height: RaSpace.md),
              DropdownButtonFormField<String>(
                initialValue: radius,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Service Radius'),
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
                onChanged: (value) =>
                    setDialogState(() => radius = value ?? radius),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
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
  }

  Future<void> editServices() async {
    const availableServices = [
      'Vehicle Towing',
      'Battery Jumpstart',
      'Flat Tyre',
      'General Mechanic',
    ];
    final selected = services.toSet();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Services Offered'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableServices.map((service) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
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
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Save Services'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final updated = availableServices
        .where((service) => selected.contains(service))
        .toList();
    try {
      await AuthService().updateCurrentProfile({'services': updated});
      if (!mounted) return;
      setState(() => services = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services updated successfully.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update services.')),
        );
      }
    }
  }

  IconData serviceIcon(String service) => switch (service) {
    'Vehicle Towing' => Icons.fire_truck_outlined,
    'Battery Jumpstart' => Icons.battery_charging_full,
    'Flat Tyre' => Icons.tire_repair,
    _ => Icons.car_repair,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Provider Profile'),
      actions: [
        IconButton(
          onPressed: editSettings,
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        if (!profileLoaded) const LinearProgressIndicator(),
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
            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            photoData == null
                                ? ProfileInitials(name: name, radius: 42)
                                : CircleAvatar(
                                    radius: 42,
                                    backgroundImage: MemoryImage(
                                      base64Decode(photoData!),
                                    ),
                                  ),
                            Positioned(
                              right: -5,
                              bottom: -5,
                              child: IconButton.filled(
                                onPressed: uploadingPhoto
                                    ? null
                                    : changeProviderPhoto,
                                tooltip: 'Change provider photo',
                                icon: uploadingPhoto
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Text(name, style: RaText.headline),
                        const SizedBox(height: RaSpace.xs),
                        const StatusPill(
                          label: 'RoadAssist Service Provider',
                          tone: RaTone.info,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                InfoStrip(
                  icon: Icons.phone_outlined,
                  title: phone,
                  value: email,
                ),
                const SizedBox(height: RaSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: editProviderProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: RaSpace.md),
        const SectionTitle('Driver Ratings'),
        const SizedBox(height: RaSpace.md),
        const _ProviderRatingSummary(),
        const SizedBox(height: RaSpace.xl),
        Card(
          child: SwitchListTile(
            secondary: IconBadge(
              accepting ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
            ),
            title: const Text('Accepting Requests', style: RaText.title),
            subtitle: Text(
              accepting ? 'Currently online' : 'Currently offline',
              style: RaText.caption,
            ),
            value: accepting,
            onChanged: (value) async {
              setState(() => accepting = value);
              if (firebaseReady) await AuthService().setProviderOnline(value);
            },
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Availability Settings'),
        const SizedBox(height: RaSpace.md),
        InfoStrip(
          icon: Icons.schedule_outlined,
          title: 'Working Hours',
          value: workingHours,
        ),
        const SizedBox(height: RaSpace.sm),
        InfoStrip(
          icon: Icons.radar_outlined,
          title: 'Service Radius',
          value: serviceRadius,
        ),
        const SizedBox(height: RaSpace.xl),
        SectionTitle(
          'Services Offered',
          action: 'Edit',
          onAction: editServices,
        ),
        const SizedBox(height: RaSpace.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: RaSpace.sm,
            mainAxisSpacing: RaSpace.sm,
            mainAxisExtent: 108,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) => ProviderServiceTile(
            icon: serviceIcon(services[index]),
            title: services[index],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        Card(
          child: ListTile(
            leading: const IconBadge(Icons.security_outlined, size: 40),
            title: const Text('Account & Security', style: RaText.title),
            subtitle: const Text('Password, verification and deletion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const AccountSecurityScreen()),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: ListTile(
            leading: const IconBadge(Icons.palette_outlined, size: 40),
            title: const Text('Appearance', style: RaText.title),
            subtitle: const Text('Light, dark or system theme'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const AppearanceScreen()),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        OutlinedButton.icon(
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) replace(context, const WelcomeScreen());
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: raDanger,
            side: const BorderSide(color: raDanger),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    ),
  );
}
