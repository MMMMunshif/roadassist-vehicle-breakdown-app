part of '../../screens.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String name = firebaseReady
      ? FirebaseAuth.instance.currentUser?.displayName ?? 'Driver'
      : 'Driver';

  String emergencyContact = 'Not added';
  String phone = 'Not added';
  String email = '';

  String? photoData;

  bool uploadingProfilePhoto = false;
  bool loadingProfile = true;
  bool profileLoadFailed = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;

  bool get emailVerified =>
      firebaseReady &&
      (FirebaseAuth.instance.currentUser?.emailVerified ?? false);

  @override
  void initState() {
    super.initState();

    if (firebaseReady && FirebaseAuth.instance.currentUser != null) {
      profileSubscription = AuthService().watchCurrentProfile().listen(
        (snapshot) {
          if (!mounted) {
            return;
          }

          final data = snapshot.data();

          setState(() {
            name = data?['displayName'] as String? ?? name;

            emergencyContact =
                data?['emergencyContact'] as String? ?? emergencyContact;

            phone = data?['phone'] as String? ?? phone;

            email =
                data?['email'] as String? ??
                FirebaseAuth.instance.currentUser?.email ??
                '';

            photoData = data?['photoData'] as String?;

            loadingProfile = false;
            profileLoadFailed = false;
          });
        },
        onError: (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            loadingProfile = false;
            profileLoadFailed = true;
          });
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

  Widget profileAvatar({double radius = 48}) {
    final source = photoData?.trim() ?? '';

    if (source.isEmpty) {
      return ProfileInitials(name: name, radius: radius);
    }

    try {
      final clean = source.contains(',') ? source.split(',').last : source;

      return ClipOval(
        child: Image.memory(
          base64Decode(clean),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return ProfileInitials(name: name, radius: radius);
          },
        ),
      );
    } catch (_) {
      return ProfileInitials(name: name, radius: radius);
    }
  }

  Future<void> changeProfilePhoto() async {
    if (uploadingProfilePhoto) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile photo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to update your RoadAssist profile photo.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 15),
                _RaDriverProfileSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photo Library',
                  subtitle: 'Choose an existing photo',
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                _RaDriverProfileSourceTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  subtitle: 'Take a new profile photo',
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.camera);
                  },
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

    final navigator = Navigator.of(context);

    final XFile? photo;

    if (source == ImageSource.camera) {
      photo = await navigator.push<XFile>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
    } else {
      photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
    }

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      uploadingProfilePhoto = true;
    });

    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);

      await AuthService().updateCurrentProfile({'photoData': encoded});

      if (!mounted) {
        return;
      }

      setState(() {
        photoData = encoded;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update photo: $error')));
    } finally {
      if (mounted) {
        setState(() {
          uploadingProfilePhoto = false;
        });
      }
    }
  }

  Future<void> editProfile() async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: name == 'Driver' ? '' : name,
    );

    final phoneController = TextEditingController(
      text: phone == 'Not added' ? '' : phone,
    );

    final emergencyController = TextEditingController(
      text: emergencyContact == 'Not added' ? '' : emergencyContact,
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.edit_outlined, color: colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Keep your contact details accurate for roadside assistance.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your name';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '07X XXX XXXX',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: validateSriLankaPhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emergencyController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact',
                      hintText: 'Name or contact number',
                      prefixIcon: Icon(Icons.contact_emergency_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter an emergency contact';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Saved vehicles are managed separately under My Vehicles.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, false);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.pop(sheetContext, true);
                            }
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      try {
        final updatedName = nameController.text.trim();

        final updatedPhone = normalizeSriLankaPhone(phoneController.text);

        final updatedEmergency = emergencyController.text.trim();

        await AuthService().updateCurrentProfile({
          'displayName': updatedName,
          'phone': updatedPhone,
          'emergencyContact': updatedEmergency,
        });

        if (!mounted) {
          return;
        }

        setState(() {
          name = updatedName;
          phone = updatedPhone;
          emergencyContact = updatedEmergency;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      } catch (error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update profile: $error')),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emergencyController.dispose();
  }

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.logout_rounded, color: colors.error),
          ),
          title: const Text('Sign out of RoadAssist?'),
          content: const Text(
            'You will need to sign in again to access your requests, messages and saved vehicles.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await AuthService().signOut();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    replace(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    if (!signedIn) {
      return RaDriverScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const RaDriverAppBarTitle('Profile'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(18),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in to manage your RoadAssist profile.',
          ),
        ),
      );
    }

    return RaDriverScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: RaDriverAppBarTitle(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: loadingProfile ? null : editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await FirebaseAuth.instance.currentUser?.reload();

            if (mounted) {
              setState(() {});
            }
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            if (loadingProfile) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],

            if (profileLoadFailed) ...[
              _RaDriverProfileNotice(
                icon: Icons.cloud_off_outlined,
                title: 'Profile sync unavailable',
                message:
                    'Some profile information may be outdated. Check your connection and try again.',
                tone: colors.error,
              ),
              const SizedBox(height: 12),
            ],

            _RaDriverProfileHero(
              name: name,
              email: email,
              emailVerified: emailVerified,
              avatar: profileAvatar(radius: 30),
              uploading: uploadingProfilePhoto,
              onPhoto: changeProfilePhoto,
              onEdit: editProfile,
            ),

            const SizedBox(height: 23),

            const _RaDriverProfileHeading(
              title: 'Personal information',
              subtitle: 'Contact information used during assistance.',
            ),

            const SizedBox(height: 10),

            _RaDriverProfileSurface(
              child: Column(
                children: [
                  _RaDriverProfileInfoRow(
                    icon: Icons.person_outline,
                    label: 'Full name',
                    value: name,
                  ),
                  const Divider(height: 1),
                  _RaDriverProfileInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: phone,
                  ),
                  const Divider(height: 1),
                  _RaDriverProfileInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email.isEmpty ? 'Not available' : email,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 23),

            const _RaDriverProfileHeading(
              title: 'Roadside setup',
              subtitle:
                  'Prepare important information before you need assistance.',
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _RaDriverProfileQuickCard(
                    icon: Icons.directions_car_outlined,
                    title: 'My Vehicles',
                    subtitle: 'Manage saved vehicles',
                    onTap: () {
                      push(context, const VehiclesScreen());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RaDriverProfileQuickCard(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Emergency',
                    subtitle: emergencyContact == 'Not added'
                        ? 'Add a contact'
                        : emergencyContact,
                    onTap: () {
                      push(context, const EmergencyScreen());
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 23),

            const _RaDriverProfileHeading(
              title: 'Settings',
              subtitle: 'Manage your RoadAssist preferences and security.',
            ),

            const SizedBox(height: 10),

            _RaDriverProfileSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _RaDriverProfileMenuTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Settings',
                    subtitle: 'Control background alerts and permissions',
                    onTap: () {
                      push(context, const NotificationSettingsScreen());
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _RaDriverProfileMenuTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Light, dark or system theme',
                    onTap: () {
                      push(context, const AppearanceScreen());
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _RaDriverProfileMenuTile(
                    icon: Icons.security_outlined,
                    title: 'Account & Security',
                    subtitle: 'Password, verification and account deletion',
                    onTap: () {
                      push(context, const AccountSecurityScreen());
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _RaDriverProfileMenuTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Safety',
                    subtitle: 'How RoadAssist uses and protects information',
                    onTap: () {
                      push(
                        context,
                        const PrivacySafetyScreen(isProvider: false),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _RaDriverProfileMenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'Get assistance using RoadAssist',
                    onTap: () {
                      push(context, const SupportScreen(isProvider: false));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: .38)),
              ),
              onPressed: signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),

            const SizedBox(height: 18),

            Center(
              child: Text(
                'ROADASSIST',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaDriverProfileHero extends StatelessWidget {
  const _RaDriverProfileHero({
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.avatar,
    required this.uploading,
    required this.onPhoto,
    required this.onEdit,
  });

  final String name;
  final String email;
  final bool emailVerified;
  final Widget avatar;
  final bool uploading;
  final VoidCallback onPhoto;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => RaProviderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                avatar,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: uploading ? null : onPhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: uploading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _providerText(
                      context,
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email.isEmpty ? 'Driver account' : email,
                    style: _providerText(context, size: 13, muted: true),
                  ),
                  const SizedBox(height: 10),
                  StatusPill(
                    label: emailVerified
                        ? 'Email verified'
                        : 'Email not verified',
                    tone: emailVerified ? RaTone.success : RaTone.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Profile'),
        ),
      ],
    ),
  );
}

class _RaDriverProfileHeading extends StatelessWidget {
  const _RaDriverProfileHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
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
    );
  }
}

class _RaDriverProfileSurface extends StatelessWidget {
  const _RaDriverProfileSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0D2237)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: child,
    );
  }
}

class _RaDriverProfileInfoRow extends StatelessWidget {
  const _RaDriverProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaDriverProfileQuickCard extends StatelessWidget {
  const _RaDriverProfileQuickCard({
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
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0D2237)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
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
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaDriverProfileMenuTile extends StatelessWidget {
  const _RaDriverProfileMenuTile({
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: colors.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _RaDriverProfileSourceTile extends StatelessWidget {
  const _RaDriverProfileSourceTile({
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
      color: colors.surfaceContainerHighest.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
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
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaDriverProfileNotice extends StatelessWidget {
  const _RaDriverProfileNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 19),
          const SizedBox(width: 8),
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
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
