part of '../../screens.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({
    super.key,
  });

  @override
  State<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState
    extends State<DriverProfileScreen> {
  String name = firebaseReady
      ? FirebaseAuth
              .instance
              .currentUser
              ?.displayName ??
          'Driver'
      : 'Driver';

  String emergencyContact =
      'Not added';

  String phone = 'Not added';

  String email = '';

  String? photoData;

  bool uploadingProfilePhoto = false;
  bool loadingProfile = true;
  bool profileLoadFailed = false;

  StreamSubscription<
          DocumentSnapshot<
              Map<String, dynamic>>>?
      profileSubscription;

  bool get emailVerified =>
      firebaseReady &&
      (FirebaseAuth
              .instance
              .currentUser
              ?.emailVerified ??
          false);

  @override
  void initState() {
    super.initState();

    if (firebaseReady &&
        FirebaseAuth
                .instance
                .currentUser !=
            null) {
      profileSubscription =
          AuthService()
              .watchCurrentProfile()
              .listen(
        (snapshot) {
          if (!mounted) return;

          final data =
              snapshot.data();

          setState(() {
            name =
                data?['displayName']
                        as String? ??
                    name;

            emergencyContact =
                data?['emergencyContact']
                        as String? ??
                    emergencyContact;

            phone =
                data?['phone']
                        as String? ??
                    phone;

            email =
                data?['email']
                        as String? ??
                    FirebaseAuth
                        .instance
                        .currentUser
                        ?.email ??
                    '';

            photoData =
                data?['photoData']
                    as String?;

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

  Widget profileAvatar({
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
          errorBuilder:
              (_, __, ___) =>
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

  String? requiredField(
    String? value,
  ) {
    return value == null ||
            value.trim().isEmpty
        ? 'This field is required'
        : null;
  }

  Future<void>
      changeProfilePhoto() async {
    final source =
        await showModalBottomSheet<
            ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: dark
                ? const Color(
                    0xFF0D1D2B,
                  )
                : colors.surface,
            borderRadius:
                const BorderRadius
                    .vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors
                        .onSurfaceVariant
                        .withValues(
                      alpha: .24,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 21),

              Text(
                'Update profile photo',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Choose a clear photo for your RoadAssist profile.',
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 10.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 17),

              _RaDriverProfilePhotoOption(
                icon: Icons
                    .photo_library_outlined,
                title:
                    'Choose from gallery',
                subtitle:
                    'Select an existing image',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    ImageSource.gallery,
                  );
                },
              ),

              const SizedBox(height: 9),

              _RaDriverProfilePhotoOption(
                icon:
                    Icons.camera_alt_outlined,
                title: 'Take a photo',
                subtitle:
                    'Use your device camera',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final navigator =
        Navigator.of(context);

    final photo =
        source == ImageSource.camera
            ? await navigator.push<XFile>(
                MaterialPageRoute(
                  builder: (_) =>
                      const CameraCaptureScreen(),
                ),
              )
            : await ImagePicker()
                .pickImage(
                source:
                    ImageSource.gallery,
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
              .prepareProfilePhoto(
        photo,
      );

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
          uploadingProfilePhoto =
              false;
        });
      }
    }
  }

  Future<void> editProfile() async {
    final formKey =
        GlobalKey<FormState>();

    final nameController =
        TextEditingController(
      text:
          name == 'Driver' ? '' : name,
    );

    final phoneController =
        TextEditingController(
      text: phone == 'Not added'
          ? ''
          : phone,
    );

    final emergencyController =
        TextEditingController(
      text: emergencyContact ==
              'Not added'
          ? ''
          : emergencyContact,
    );

    final saved =
        await showModalBottomSheet<
            bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        final dark =
            theme.brightness ==
                Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              sheetContext,
            ).viewInsets.bottom,
          ),
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              24,
            ),
            decoration: BoxDecoration(
              color: dark
                  ? const Color(
                      0xFF0D1D2B,
                    )
                  : colors.surface,
              borderRadius:
                  const BorderRadius
                      .vertical(
                top:
                    Radius.circular(28),
              ),
            ),
            child:
                SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration:
                            BoxDecoration(
                          color: colors
                              .onSurfaceVariant
                              .withValues(
                            alpha: .24,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            999,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 21,
                    ),

                    Text(
                      'Edit profile',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 19,
                        fontWeight:
                            FontWeight
                                .w800,
                        color: colors
                            .onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Keep your contact information up to date.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    TextFormField(
                      controller:
                          nameController,
                      textCapitalization:
                          TextCapitalization
                              .words,
                      textInputAction:
                          TextInputAction
                              .next,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Full name',
                        prefixIcon: Icon(
                          Icons
                              .person_outline_rounded,
                        ),
                      ),
                      validator:
                          requiredField,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextFormField(
                      controller:
                          phoneController,
                      keyboardType:
                          TextInputType
                              .phone,
                      textInputAction:
                          TextInputAction
                              .next,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Phone number',
                        hintText:
                            '077 123 4567',
                        prefixIcon: Icon(
                          Icons
                              .phone_outlined,
                        ),
                      ),
                      validator:
                          validateSriLankaPhone,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextFormField(
                      controller:
                          emergencyController,
                      textInputAction:
                          TextInputAction
                              .done,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Emergency contact',
                        hintText:
                            'Name or contact number',
                        prefixIcon: Icon(
                          Icons
                              .contact_emergency_outlined,
                        ),
                      ),
                      validator:
                          requiredField,
                    ),

                    const SizedBox(
                      height: 19,
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
                          width: 9,
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
                            icon:
                                const Icon(
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
            emergencyController.text
                .trim();

        if (firebaseReady) {
          await AuthService()
              .updateCurrentProfile({
            'displayName':
                updatedName,
            'phone':
                updatedPhone,
            'emergencyContact':
                updatedContact,
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.error
                  .withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(
                17,
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
            'You will need to sign in again to access requests, messages and saved vehicles.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Sign Out',
              ),
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
      // Allows non-Firebase prototype tests to continue.
    }

    if (!mounted) return;

    replace(
      context,
      const WelcomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading:
            Navigator.of(context).canPop(),
        title: Text(
          'Profile',
          style: GoogleFonts
              .plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
      ),
      body: ListView(
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          34,
        ),
        children: [
          if (loadingProfile)
            const LinearProgressIndicator(
              minHeight: 3,
            ),

          if (profileLoadFailed) ...[
            _RaDriverProfileNotice(
              icon:
                  Icons.cloud_off_outlined,
              text:
                  'Some profile information could not be loaded.',
              tone: colors.error,
            ),
            const SizedBox(height: 12),
          ],

          _RaDriverProfileHero(
            name: name,
            email: email,
            avatar: profileAvatar(
              radius: 46,
            ),
            emailVerified:
                emailVerified,
            uploading:
                uploadingProfilePhoto,
            onPhoto:
                changeProfilePhoto,
            onEdit: editProfile,
          ),

          const SizedBox(height: 26),

          _RaDriverProfileHeading(
            title:
                'Personal information',
            subtitle:
                'Details used during roadside assistance.',
            action: 'Edit',
            onAction: editProfile,
          ),

          const SizedBox(height: 10),

          _RaDriverProfileInfoCard(
            name: name,
            phone: phone,
            email: email,
            verified:
                emailVerified,
          ),

          const SizedBox(height: 26),

          const _RaDriverProfileHeading(
            title: 'Roadside setup',
            subtitle:
                'Prepare important information before you need help.',
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child:
                    _RaDriverProfileAction(
                  icon: Icons
                      .directions_car_outlined,
                  title: 'Vehicles',
                  subtitle:
                      'Saved profiles',
                  onTap: () {
                    push(
                      context,
                      const VehiclesScreen(),
                    );
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child:
                    _RaDriverProfileAction(
                  icon: Icons
                      .contact_emergency_outlined,
                  title: 'Emergency',
                  subtitle:
                      emergencyContact ==
                              'Not added'
                          ? 'Add contact'
                          : emergencyContact,
                  onTap: () {
                    push(
                      context,
                      const EmergencyScreen(),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          const _RaDriverProfileHeading(
            title: 'Settings',
            subtitle:
                'Control your RoadAssist experience.',
          ),

          const SizedBox(height: 10),

          _RaDriverProfileMenu(
            children: [
              _RaDriverProfileMenuTile(
                icon: Icons
                    .notifications_none_rounded,
                title: 'Notifications',
                subtitle:
                    'Request and service activity',
                onTap: () {
                  push(
                    context,
                    const DriverNotificationsScreen(),
                  );
                },
              ),

              _RaDriverProfileMenuTile(
                icon: Icons
                    .notifications_active_outlined,
                title:
                    'Push Notifications',
                subtitle:
                    'Manage this device',
                onTap: () {
                  push(
                    context,
                    const NotificationSettingsScreen(),
                  );
                },
              ),

              _RaDriverProfileMenuTile(
                icon:
                    Icons.palette_outlined,
                title: 'Appearance',
                subtitle:
                    'Light, dark or system theme',
                onTap: () {
                  push(
                    context,
                    const AppearanceScreen(),
                  );
                },
              ),

              _RaDriverProfileMenuTile(
                icon:
                    Icons.security_outlined,
                title:
                    'Account & Security',
                subtitle:
                    'Password, verification and account access',
                onTap: () {
                  push(
                    context,
                    const AccountSecurityScreen(),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          _RaDriverProfileMenu(
            children: [
              _RaDriverProfileMenuTile(
                icon: Icons
                    .privacy_tip_outlined,
                title:
                    'Privacy & Safety',
                subtitle:
                    'Location and account privacy',
                onTap: () {
                  push(
                    context,
                    const PrivacySafetyScreen(
                      isProvider: false,
                    ),
                  );
                },
              ),

              _RaDriverProfileMenuTile(
                icon: Icons
                    .help_outline_rounded,
                title:
                    'Help & Support',
                subtitle:
                    'Get help using RoadAssist',
                onTap: () {
                  push(
                    context,
                    const SupportScreen(
                      isProvider: false,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 25),

          OutlinedButton.icon(
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  colors.error,
              side: BorderSide(
                color: colors.error
                    .withValues(
                  alpha: .40,
                ),
              ),
            ),
            onPressed: signOut,
            icon: const Icon(
              Icons.logout_rounded,
            ),
            label: const Text(
              'Sign Out',
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'RoadAssist',
              style: GoogleFonts
                  .plusJakartaSans(
                fontSize: 9,
                fontWeight:
                    FontWeight.w600,
                letterSpacing: 1,
                color: colors
                    .onSurfaceVariant
                    .withValues(
                  alpha: .60,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaDriverProfileHero
    extends StatelessWidget {
  const _RaDriverProfileHero({
    required this.name,
    required this.email,
    required this.avatar,
    required this.emailVerified,
    required this.uploading,
    required this.onPhoto,
    required this.onEdit,
  });

  final String name;
  final String email;
  final Widget avatar;
  final bool emailVerified;
  final bool uploading;

  final VoidCallback onPhoto;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B487E),
                  Color(0xFF08645D),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior:
                    Clip.none,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      3,
                    ),
                    decoration:
                        BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(
                          alpha: .48,
                        ),
                      ),
                    ),
                    child: avatar,
                  ),

                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Material(
                      color: Colors.white,
                      shape:
                          const CircleBorder(),
                      child: InkWell(
                        customBorder:
                            const CircleBorder(),
                        onTap: uploading
                            ? null
                            : onPhoto,
                        child: SizedBox(
                          width: 31,
                          height: 31,
                          child: uploading
                              ? const Padding(
                                  padding:
                                      EdgeInsets
                                          .all(
                                    8,
                                  ),
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .camera_alt_rounded,
                                  size: 16,
                                  color:
                                      Color(
                                    0xFF075BA8,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts
                          .plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    if (email
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: GoogleFonts
                            .plusJakartaSans(
                          color: Colors.white
                              .withValues(
                            alpha: .74,
                          ),
                          fontSize: 9.5,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 9,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: .12,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          999,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            emailVerified
                                ? Icons
                                    .verified_rounded
                                : Icons
                                    .schedule_rounded,
                            color:
                                Colors.white,
                            size: 13,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            emailVerified
                                ? 'Email verified'
                                : 'Verification pending',
                            style: GoogleFonts
                                .plusJakartaSans(
                              color:
                                  Colors.white,
                              fontSize: 8.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Edit profile',
                onPressed: onEdit,
                style:
                    IconButton.styleFrom(
                  backgroundColor:
                      Colors.white
                          .withValues(
                    alpha: .11,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 19,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .08),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .shield_outlined,
                  color: Colors.white,
                  size: 18,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Your profile helps providers identify and contact you during active roadside assistance.',
                    style: GoogleFonts
                        .plusJakartaSans(
                      color: Colors.white
                          .withValues(
                        alpha: .78,
                      ),
                      fontSize: 9.5,
                      height: 1.4,
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

class _RaDriverProfileHeading
    extends StatelessWidget {
  const _RaDriverProfileHeading({
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
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts
                    .plusJakartaSans(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts
                    .plusJakartaSans(
                  color: colors
                      .onSurfaceVariant,
                  fontSize: 10,
                  height: 1.4,
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

class _RaDriverProfileInfoCard
    extends StatelessWidget {
  const _RaDriverProfileInfoCard({
    required this.name,
    required this.phone,
    required this.email,
    required this.verified,
  });

  final String name;
  final String phone;
  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return _RaDriverProfileMenu(
      children: [
        _RaDriverProfileInfoRow(
          icon: Icons.person_outline,
          label: 'Full name',
          value: name,
        ),
        _RaDriverProfileInfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: phone,
        ),
        _RaDriverProfileInfoRow(
          icon:
              Icons.alternate_email_rounded,
          label: 'Email',
          value: email.trim().isEmpty
              ? 'Not available'
              : email,
          suffix: verified
              ? const Icon(
                  Icons.verified_rounded,
                  color: raSuccess,
                  size: 17,
                )
              : null,
        ),
      ],
    );
  }
}

class _RaDriverProfileInfoRow
    extends StatelessWidget {
  const _RaDriverProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 8.5,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        colors.onSurface,
                  ),
                ),
              ],
            ),
          ),

          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix!,
          ],
        ],
      ),
    );
  }
}

class _RaDriverProfileAction
    extends StatelessWidget {
  const _RaDriverProfileAction({
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
    final dark =
        theme.brightness == Brightness.dark;

    return Material(
      color: dark
          ? const Color(0xFF0D1D2B)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints:
              const BoxConstraints(
            minHeight: 116,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(19),
            border: Border.all(
              color: colors.outlineVariant
                  .withValues(alpha: .48),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colors.primary,
                ),
              ),

              const Spacer(),

              Text(
                title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts
                    .plusJakartaSans(
                  fontSize: 8.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaDriverProfileMenu
    extends StatelessWidget {
  const _RaDriverProfileMenu({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D1D2B)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .48),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0;
              i < children.length;
              i++) ...[
            children[i],
            if (i !=
                children.length - 1)
              Divider(
                height: 1,
                indent: 55,
                color: colors
                    .outlineVariant
                    .withValues(
                  alpha: .35,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RaDriverProfileMenuTile
    extends StatelessWidget {
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
    final colors =
        Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      onTap: onTap,
      leading: Container(
        width: 37,
        height: 37,
        decoration: BoxDecoration(
          color: colors.primary
              .withValues(alpha: .08),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: colors.primary,
          size: 18,
        ),
      ),
      title: Text(
        title,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 8.8,
          color:
              colors.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}

class _RaDriverProfilePhotoOption
    extends StatelessWidget {
  const _RaDriverProfilePhotoOption({
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
      color: colors
          .surfaceContainerHighest
          .withValues(alpha: .35),
      borderRadius:
          BorderRadius.circular(17),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(
                    alpha: .09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

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
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 9,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color:
                    colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaDriverProfileNotice
    extends StatelessWidget {
  const _RaDriverProfileNotice({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: .08),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: tone,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}