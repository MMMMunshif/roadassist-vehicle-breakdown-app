part of '../screens.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String name = firebaseReady
      ? FirebaseAuth.instance.currentUser?.displayName ?? 'Driver'
      : 'Driver';
  String vehicle = 'Not added';
  String emergencyContact = 'Not added';
  String phone = 'Not added';
  String email = '';
  String? photoData;
  bool uploadingProfilePhoto = false;
  bool loadingProfile = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;

  @override
  void initState() {
    super.initState();
    if (firebaseReady && FirebaseAuth.instance.currentUser != null) {
      profileSubscription = AuthService().watchCurrentProfile().listen(
        (snapshot) {
          if (!mounted) return;
          final data = snapshot.data();
          setState(() {
            name = data?['displayName'] as String? ?? name;
            vehicle = data?['vehicle'] as String? ?? vehicle;
            emergencyContact =
                data?['emergencyContact'] as String? ?? emergencyContact;
            phone = data?['phone'] as String? ?? phone;
            email =
                data?['email'] as String? ??
                FirebaseAuth.instance.currentUser?.email ??
                '';
            photoData = data?['photoData'] as String?;
            loadingProfile = false;
          });
        },
        onError: (_) {
          if (mounted) setState(() => loadingProfile = false);
        },
      );
    } else {
      loadingProfile = false;
    }
  }

  @override
  void dispose() {
    profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> changeProfilePhoto() async {
    final navigator = Navigator.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => const SafeArea(
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
    setState(() => uploadingProfilePhoto = true);
    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);
      await AuthService().updateCurrentProfile({'photoData': encoded});
      if (!mounted) return;
      setState(() => photoData = encoded);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
    } finally {
      if (mounted) setState(() => uploadingProfilePhoto = false);
    }
  }

  Future<void> editProfile() async {
    final formKey = GlobalKey<FormState>();
    var updatedName = name;
    var updatedVehicle = vehicle;
    var updatedContact = emergencyContact;
    var updatedPhone = phone;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  onChanged: (value) => updatedName = value,
                  validator: requiredField,
                ),
                const SizedBox(height: RaSpace.md),
                TextFormField(
                  initialValue: vehicle,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle and Registration',
                  ),
                  onChanged: (value) => updatedVehicle = value,
                  validator: requiredField,
                ),
                const SizedBox(height: RaSpace.md),
                TextFormField(
                  initialValue: emergencyContact,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact',
                  ),
                  onChanged: (value) => updatedContact = value,
                  validator: requiredField,
                ),
                const SizedBox(height: RaSpace.md),
                TextFormField(
                  initialValue: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  onChanged: (value) => updatedPhone = value,
                  validator: validateSriLankaPhone,
                ),
              ],
            ),
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      try {
        if (firebaseReady) {
          await AuthService().updateCurrentProfile({
            'displayName': updatedName.trim(),
            'vehicle': updatedVehicle.trim(),
            'emergencyContact': updatedContact.trim(),
            'phone': normalizeSriLankaPhone(updatedPhone),
          });
        }
        if (!mounted) return;
        setState(() {
          name = updatedName.trim();
          vehicle = updatedVehicle.trim();
          emergencyContact = updatedContact.trim();
          phone = normalizeSriLankaPhone(updatedPhone);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to update profile: $error')),
          );
      }
    }
  }

  String? requiredField(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout, color: raBlue),
        title: const Text('Sign out of RoadAssist?'),
        content: const Text('You will return to the welcome screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await AuthService().signOut();
      } catch (_) {
        // Prototype widget tests do not initialize Firebase.
      }
      if (!mounted) return;
      replace(context, const WelcomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        if (loadingProfile) const LinearProgressIndicator(),
        if (loadingProfile) const SizedBox(height: RaSpace.lg),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              photoData == null
                  ? ProfileInitials(name: name, radius: 48)
                  : ClipOval(
                      child: Image.memory(
                        base64Decode(photoData!),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ProfileInitials(name: name, radius: 48),
                      ),
                    ),
              Positioned(
                right: -6,
                bottom: -6,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: raBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: uploadingProfilePhoto ? null : changeProfilePhoto,
                  tooltip: 'Change profile photo',
                  icon: uploadingProfilePhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 19),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.md),
        Text(name, textAlign: TextAlign.center, style: RaText.headline),
        const SizedBox(height: 2),
        const Center(
          child: StatusPill(label: 'Verified Driver', tone: RaTone.success),
        ),
        const SizedBox(height: RaSpace.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: editProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Personal Information'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RaSpace.lg,
              vertical: RaSpace.sm,
            ),
            child: Column(
              children: [
                _ProfileInfoRow(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: name,
                ),
                const Divider(height: 1),
                _ProfileInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone Number',
                  value: phone,
                ),
                const Divider(height: 1),
                _ProfileInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: email.isEmpty ? 'Not added' : email,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(RaRadius.lg),
            onTap: editProfile,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Row(
                children: [
                  const IconBadge(Icons.directions_car_outlined, size: 40),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Vehicle', style: RaText.title),
                        const SizedBox(height: 3),
                        Text(vehicle, style: RaText.bodyMuted),
                      ],
                    ),
                  ),
                  const Text(
                    'Edit',
                    style: TextStyle(
                      color: raBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: raBlue, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(RaRadius.lg),
            onTap: () => push(context, const EmergencyScreen()),
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Row(
                children: [
                  const IconBadge(Icons.contact_emergency_outlined, size: 40),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Emergency Contact', style: RaText.title),
                        const SizedBox(height: 3),
                        Text(emergencyContact, style: RaText.bodyMuted),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'Primary',
                    tone: RaTone.info,
                    dot: false,
                  ),
                  const Icon(Icons.chevron_right, color: raMuted, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconBadge(
                  Icons.notifications_none_outlined,
                  size: 36,
                ),
                title: const Text('Notifications', style: RaText.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const DriverNotificationsScreen()),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                leading: const IconBadge(
                  Icons.directions_car_outlined,
                  size: 36,
                ),
                title: const Text('My Vehicles', style: RaText.title),
                subtitle: const Text(
                  'Save, edit and choose your default vehicle',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const VehiclesScreen()),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                leading: const IconBadge(Icons.palette_outlined, size: 36),
                title: const Text('Appearance', style: RaText.title),
                subtitle: const Text('Light, dark or system theme'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const AppearanceScreen()),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                leading: const IconBadge(Icons.help_outline, size: 36),
                title: const Text('Help & Support', style: RaText.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    push(context, const SupportScreen(isProvider: false)),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                leading: const IconBadge(Icons.security_outlined, size: 36),
                title: const Text('Account & Security', style: RaText.title),
                subtitle: const Text('Password, verification and deletion'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const AccountSecurityScreen()),
              ),
              const Divider(height: 1, indent: 58),
              ListTile(
                leading: const IconBadge(Icons.privacy_tip_outlined, size: 36),
                title: const Text('Privacy & Security', style: RaText.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Privacy & Security'),
                    content: const Text(
                      'Your profile is private. Only the provider assigned to your active request can access the contact and breakdown details needed to assist you.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        OutlinedButton.icon(
          onPressed: signOut,
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
