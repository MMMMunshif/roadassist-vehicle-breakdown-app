part of '../../screens.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
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

    if (firebaseReady &&
        FirebaseAuth.instance.currentUser != null) {
      profileSubscription =
          AuthService().watchCurrentProfile().listen(
        (snapshot) {
          if (!mounted) return;

          final data = snapshot.data();

          setState(() {
            name =
                data?['displayName'] as String? ?? name;

            emergencyContact =
                data?['emergencyContact'] as String? ??
                    emergencyContact;

            phone =
                data?['phone'] as String? ?? phone;

            email =
                data?['email'] as String? ??
                    FirebaseAuth.instance.currentUser?.email ??
                    '';

            photoData =
                data?['photoData'] as String?;

            loadingProfile = false;
            profileLoadFailed = false;
          });
        },
        onError: (_) {
          if (!mounted) return;

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

  Widget _profileAvatar({
    double radius = 50,
  }) {
    if (photoData == null ||
        photoData!.trim().isEmpty) {
      return ProfileInitials(
        name: name,
        radius: radius,
      );
    }

    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(photoData!),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              ProfileInitials(
            name: name,
            radius: radius,
          ),
        ),
      );
    } on FormatException {
      return ProfileInitials(
        name: name,
        radius: radius,
      );
    }
  }

  Future<void> changeProfilePhoto() async {
    final source =
        await showModalBottomSheet<ImageSource>(
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
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update profile photo',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a clear photo for your RoadAssist profile.',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(
                  height: RaSpace.lg,
                ),
                _DriverProfilePhotoSourceTile(
                  icon:
                      Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  subtitle:
                      'Select an existing photo from your device',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(
                  height: RaSpace.sm,
                ),
                _DriverProfilePhotoSourceTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  subtitle:
                      'Use your camera to take a new profile photo',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.camera,
                    );
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

    final navigator =
        Navigator.of(context);

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

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      uploadingProfilePhoto = true;
    });

    try {
      final encoded =
          await PhotoUploadService()
              .prepareProfilePhoto(photo);

      await AuthService()
          .updateCurrentProfile({
        'photoData': encoded,
      });

      if (!mounted) return;

      setState(() {
        photoData = encoded;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Photo upload failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingProfilePhoto = false;
        });
      }
    }
  }

  Future<void> editProfile() async {
    final formKey =
        GlobalKey<FormState>();

    final nameController =
        TextEditingController(
      text: name == 'Driver' ? '' : name,
    );

    final phoneController =
        TextEditingController(
      text: phone == 'Not added' ? '' : phone,
    );

    final emergencyController =
        TextEditingController(
      text: emergencyContact == 'Not added'
          ? ''
          : emergencyContact,
    );

    final saved =
        await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            MediaQuery.of(sheetContext)
                    .viewInsets
                    .bottom +
                RaSpace.lg,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration:
                            BoxDecoration(
                          color: theme
                              .colorScheme
                              .primaryContainer,
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: theme
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(
                        width: RaSpace.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Edit profile',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              'Keep your contact information up to date.',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: RaSpace.xl,
                  ),

                  TextFormField(
                    controller:
                        nameController,
                    textCapitalization:
                        TextCapitalization.words,
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon:
                          Icon(
                        Icons.person_outline,
                      ),
                    ),
                    validator: requiredField,
                  ),

                  const SizedBox(
                    height: RaSpace.md,
                  ),

                  TextFormField(
                    controller:
                        phoneController,
                    keyboardType:
                        TextInputType.phone,
                    textInputAction:
                        TextInputAction.next,
                    decoration:
                        const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon:
                          Icon(
                        Icons.phone_outlined,
                      ),
                      hintText:
                          '07X XXX XXXX',
                    ),
                    validator:
                        validateSriLankaPhone,
                  ),

                  const SizedBox(
                    height: RaSpace.md,
                  ),

                  TextFormField(
                    controller:
                        emergencyController,
                    textInputAction:
                        TextInputAction.done,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Emergency contact',
                      prefixIcon:
                          Icon(
                        Icons
                            .contact_emergency_outlined,
                      ),
                      hintText:
                          'Name or contact number',
                    ),
                    validator: requiredField,
                  ),

                  const SizedBox(
                    height: RaSpace.sm,
                  ),

                  Text(
                    'Vehicle details are managed separately under My Vehicles.',
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),

                  const SizedBox(
                    height: RaSpace.xl,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              false,
                            );
                          },
                          child:
                              const Text(
                            'Cancel',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: RaSpace.sm,
                      ),
                      Expanded(
                        flex: 2,
                        child:
                            FilledButton.icon(
                          onPressed: () {
                            if (formKey
                                    .currentState
                                    ?.validate() ??
                                false) {
                              Navigator.pop(
                                sheetContext,
                                true,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons
                                .check_rounded,
                          ),
                          label:
                              const Text(
                            'Save Changes',
                          ),
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
        final updatedName =
            nameController.text.trim();

        final updatedPhone =
            normalizeSriLankaPhone(
          phoneController.text,
        );

        final updatedContact =
            emergencyController.text.trim();

        if (firebaseReady) {
          await AuthService()
              .updateCurrentProfile({
            'displayName': updatedName,
            'emergencyContact':
                updatedContact,
            'phone': updatedPhone,
          });
        }

        if (!mounted) return;

        setState(() {
          name = updatedName;
          phone = updatedPhone;
          emergencyContact =
              updatedContact;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update profile: $error',
            ),
          ),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emergencyController.dispose();
  }

  String? requiredField(
    String? value,
  ) {
    return value == null ||
            value.trim().isEmpty
        ? 'This field is required'
        : null;
  }

  Future<void> _showPrivacyInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors =
            Theme.of(sheetContext)
                .colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.lg,
              0,
              RaSpace.lg,
              RaSpace.lg,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .privacy_tip_outlined,
                    color: colors
                        .onPrimaryContainer,
                  ),
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Text(
                  'Privacy & Safety',
                  style: Theme.of(
                    sheetContext,
                  )
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                Text(
                  'Your RoadAssist profile is private. Contact and breakdown information required for roadside assistance is shared only with the provider involved in your request.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyMedium,
                ),

                const SizedBox(
                  height: RaSpace.lg,
                ),

                _DriverPrivacyPoint(
                  icon: Icons
                      .person_outline_rounded,
                  title:
                      'Profile information',
                  text:
                      'Your profile details are used to identify and contact you during assistance.',
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                _DriverPrivacyPoint(
                  icon: Icons
                      .location_on_outlined,
                  title:
                      'Location information',
                  text:
                      'Location is used when needed to connect you with roadside assistance.',
                ),

                const SizedBox(
                  height: RaSpace.sm,
                ),

                _DriverPrivacyPoint(
                  icon: Icons
                      .lock_outline_rounded,
                  title:
                      'Request access',
                  text:
                      'Job information is limited to participants who need it for the assistance workflow.',
                ),

                const SizedBox(
                  height: RaSpace.lg,
                ),

                FilledButton(
                  onPressed: () =>
                      Navigator.pop(
                    sheetContext,
                  ),
                  child: const Text(
                    'Done',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> signOut() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors
                  .errorContainer,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: Icon(
              Icons.logout_rounded,
              color: colors.error,
            ),
          ),
          title: const Text(
            'Sign out of RoadAssist?',
          ),
          content: const Text(
            'You will need to sign in again to access your requests, messages and saved vehicles.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    try {
      await AuthService().signOut();
    } catch (_) {
      // Prototype tests may not initialize Firebase.
    }

    if (!mounted) return;

    replace(
      context,
      const WelcomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              false,
          title:
              const Text('Profile'),
        ),
        body: const Padding(
          padding:
              EdgeInsets.all(
            RaSpace.lg,
          ),
          child: EmptyState(
            icon:
                Icons.login_outlined,
            title:
                'Sign in required',
            message:
                'Sign in to view and manage your RoadAssist profile.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        titleSpacing:
            RaSpace.lg,
        title:
            const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed:
                loadingProfile
                    ? null
                    : editProfile,
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          const SizedBox(
            width: RaSpace.sm,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          if (!firebaseReady) {
            return;
          }

          try {
            await FirebaseAuth
                .instance.currentUser
                ?.reload();

            if (mounted) {
              setState(() {});
            }
          } catch (_) {}
        },
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.sm,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            if (loadingProfile) ...[
              const LinearProgressIndicator(
                minHeight: 3,
              ),
              const SizedBox(
                height: RaSpace.md,
              ),
            ],

            if (profileLoadFailed) ...[
              _DriverProfileNotice(
                icon:
                    Icons.cloud_off_outlined,
                title:
                    'Profile sync unavailable',
                message:
                    'Some information may not be up to date. Check your connection and try again.',
                tone:
                    colors.errorContainer,
                foreground:
                    colors.onErrorContainer,
              ),
              const SizedBox(
                height: RaSpace.md,
              ),
            ],

            _DriverProfileHero(
              name: name,
              email: email,
              avatar:
                  _profileAvatar(
                radius: 49,
              ),
              emailVerified:
                  emailVerified,
              uploading:
                  uploadingProfilePhoto,
              onChangePhoto:
                  changeProfilePhoto,
              onEdit:
                  editProfile,
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            _DriverProfileSectionHeader(
              title:
                  'Personal information',
              subtitle:
                  'Details used for your RoadAssist account.',
              actionLabel: 'Edit',
              onAction: editProfile,
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            _DriverProfileInfoCard(
              name: name,
              phone: phone,
              email: email,
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            const _DriverProfileSectionHeader(
              title:
                  'Roadside setup',
              subtitle:
                  'Manage important information before you need assistance.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _DriverProfileActionCard(
                    icon: Icons
                        .directions_car_outlined,
                    title:
                        'My Vehicles',
                    subtitle:
                        'Saved vehicle profiles',
                    onTap: () =>
                        push(
                      context,
                      const VehiclesScreen(),
                    ),
                  ),
                ),

                const SizedBox(
                  width: RaSpace.sm,
                ),

                Expanded(
                  child:
                      _DriverProfileActionCard(
                    icon: Icons
                        .contact_emergency_outlined,
                    title:
                        'Emergency',
                    subtitle:
                        emergencyContact ==
                                'Not added'
                            ? 'Add a contact'
                            : emergencyContact,
                    onTap: () =>
                        push(
                      context,
                      const EmergencyScreen(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            const _DriverProfileSectionHeader(
              title: 'Settings',
              subtitle:
                  'Customize your account and app experience.',
            ),

            const SizedBox(
              height: RaSpace.sm,
            ),

            _DriverProfileMenuGroup(
              children: [
                _DriverProfileMenuTile(
                  icon: Icons
                      .notifications_none_rounded,
                  title:
                      'Notifications',
                  subtitle:
                      'Request and service updates',
                  onTap: () => push(
                    context,
                    const DriverNotificationsScreen(),
                  ),
                ),

                _DriverProfileMenuTile(
                  icon:
                      Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle:
                      'Light, dark or system theme',
                  onTap: () => push(
                    context,
                    const AppearanceScreen(),
                  ),
                ),

                _DriverProfileMenuTile(
                  icon: Icons
                      .security_outlined,
                  title:
                      'Account & Security',
                  subtitle:
                      'Password, verification and account access',
                  onTap: () => push(
                    context,
                    const AccountSecurityScreen(),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.md,
            ),

            _DriverProfileMenuGroup(
              children: [
                _DriverProfileMenuTile(
                  icon: Icons
                      .privacy_tip_outlined,
                  title:
                      'Privacy & Safety',
                  subtitle:
                      'Understand how your information is used',
                  onTap:
                      _showPrivacyInfo,
                ),

                _DriverProfileMenuTile(
                  icon:
                      Icons.help_outline_rounded,
                  title:
                      'Help & Support',
                  subtitle:
                      'Get help using RoadAssist',
                  onTap: () => push(
                    context,
                    const SupportScreen(
                      isProvider: false,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: RaSpace.xl,
            ),

            _DriverProfileSignOutButton(
              onPressed: signOut,
            ),

            const SizedBox(
              height: RaSpace.lg,
            ),

            Center(
              child: Text(
                'RoadAssist',
                style: theme
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProfileHero
    extends StatelessWidget {
  const _DriverProfileHero({
    required this.name,
    required this.email,
    required this.avatar,
    required this.emailVerified,
    required this.uploading,
    required this.onChangePhoto,
    required this.onEdit,
  });

  final String name;
  final String email;
  final Widget avatar;

  final bool emailVerified;
  final bool uploading;

  final VoidCallback onChangePhoto;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final dark =
        theme.brightness ==
            Brightness.dark;

    final start = dark
        ? const Color(0xFF0B4F88)
        : colors.primary;

    final end = dark
        ? const Color(0xFF076A62)
        : const Color(0xFF007D70);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            start,
            end,
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          26,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary
                .withValues(
              alpha: dark ? .12 : .16,
            ),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(
                  alpha: .06,
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: -35,
            child: Icon(
              Icons
                  .person_outline_rounded,
              size: 140,
              color: Colors.white
                  .withValues(
                alpha: .045,
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              RaSpace.xl,
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior:
                      Clip.none,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets
                              .all(
                        4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: .20,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                      child: avatar,
                    ),

                    Positioned(
                      right: -3,
                      bottom: -3,
                      child:
                          IconButton.filled(
                        tooltip:
                            'Change photo',
                        onPressed:
                            uploading
                                ? null
                                : onChangePhoto,
                        style: IconButton
                            .styleFrom(
                          backgroundColor:
                              Colors.white,
                          foregroundColor:
                              colors.primary,
                        ),
                        icon: uploading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color: colors
                                      .primary,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .photo_camera_outlined,
                                size: 19,
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: RaSpace.md,
                ),

                Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    email,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: Colors
                          .white
                          .withValues(
                        alpha: .78,
                      ),
                    ),
                  ),
                ],

                const SizedBox(
                  height: RaSpace.md,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        RaSpace.md,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: .13,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                    border: Border.all(
                      color: Colors.white
                          .withValues(
                        alpha: .15,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        emailVerified
                            ? Icons
                                .verified_outlined
                            : Icons
                                .mail_outline_rounded,
                        color:
                            Colors.white,
                        size: 16,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Text(
                        emailVerified
                            ? 'Email verified'
                            : 'Email verification pending',
                        style: theme
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: RaSpace.lg,
                ),

                SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed: onEdit,
                    style: FilledButton
                        .styleFrom(
                      backgroundColor:
                          Colors.white,
                      foregroundColor:
                          colors.primary,
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                    label: const Text(
                      'Edit Profile',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileSectionHeader
    extends StatelessWidget {
  const _DriverProfileSectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null &&
            onAction != null)
          TextButton(
            onPressed: onAction,
            child:
                Text(actionLabel!),
          ),
      ],
    );
  }
}

class _DriverProfileInfoCard
    extends StatelessWidget {
  const _DriverProfileInfoCard({
    required this.name,
    required this.phone,
    required this.email,
  });

  final String name;
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      child: Column(
        children: [
          _DriverProfileInfoRow(
            icon:
                Icons.person_outline,
            label: 'Full name',
            value: name,
          ),
          Divider(
            height: 1,
            indent: 62,
            color: colors
                .outlineVariant
                .withValues(
              alpha: .55,
            ),
          ),
          _DriverProfileInfoRow(
            icon:
                Icons.phone_outlined,
            label: 'Phone number',
            value: phone,
          ),
          Divider(
            height: 1,
            indent: 62,
            color: colors
                .outlineVariant
                .withValues(
              alpha: .55,
            ),
          ),
          _DriverProfileInfoRow(
            icon:
                Icons.email_outlined,
            label: 'Email address',
            value: email.isEmpty
                ? 'Not added'
                : email,
          ),
        ],
      ),
    );
  }
}

class _DriverProfileInfoRow
    extends StatelessWidget {
  const _DriverProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.all(
        RaSpace.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer
                  .withValues(
                alpha: .6,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colors
                  .onPrimaryContainer,
            ),
          ),

          const SizedBox(
            width: RaSpace.md,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileActionCard
    extends StatelessWidget {
  const _DriverProfileActionCard({
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
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(
        19,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints:
              const BoxConstraints(
            minHeight: 150,
          ),
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .6,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(height: RaSpace.md),

              Text(
                title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: RaSpace.sm,
              ),

              Align(
                alignment:
                    Alignment.centerRight,
                child: Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 19,
                  color:
                      colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverProfileMenuGroup
    extends StatelessWidget {
  const _DriverProfileMenuGroup({
    required this.children,
  });

  final List<_DriverProfileMenuTile>
      children;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0;
              index < children.length;
              index++) ...[
            children[index],
            if (index !=
                children.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .55,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DriverProfileMenuTile
    extends StatelessWidget {
  const _DriverProfileMenuTile({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: RaSpace.md,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(
                    alpha: .65,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: colors.primary,
                ),
              ),

              const SizedBox(
                width: RaSpace.md,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: RaSpace.sm,
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: colors
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverProfileSignOutButton
    extends StatelessWidget {
  const _DriverProfileSignOutButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            colors.error,
        side: BorderSide(
          color: colors.error
              .withValues(alpha: .45),
        ),
        backgroundColor:
            colors.errorContainer
                .withValues(alpha: .18),
        minimumSize:
            const Size(
          double.infinity,
          52,
        ),
      ),
      icon: const Icon(
        Icons.logout_rounded,
      ),
      label:
          const Text('Sign Out'),
    );
  }
}

class _DriverProfilePhotoSourceTile
    extends StatelessWidget {
  const _DriverProfilePhotoSourceTile({
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
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            RaSpace.md,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: .65,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: colors
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(
                width: RaSpace.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons
                    .chevron_right_rounded,
                color: colors
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverPrivacyPoint
    extends StatelessWidget {
  const _DriverPrivacyPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: colors.primary,
          ),
        ),
        const SizedBox(
          width: RaSpace.md,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverProfileNotice
    extends StatelessWidget {
  const _DriverProfileNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        RaSpace.md,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: .55,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: foreground,
          ),
          const SizedBox(
            width: RaSpace.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    color: foreground,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}