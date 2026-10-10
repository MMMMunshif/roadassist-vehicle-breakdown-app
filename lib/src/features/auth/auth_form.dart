part of '../../screens.dart';

class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.isProvider, this.initialRegisterMode = false});

  final bool isProvider;
  final bool initialRegisterMode;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  late bool registerMode;

  bool obscure = true;
  bool loading = false;

  String? registrationPhotoData;
  bool preparingRegistrationPhoto = false;

  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  AuthService get authService => AuthService();

  bool get isProvider => widget.isProvider;

  String get roleName => isProvider ? 'Provider' : 'Driver';

  Color get roleAccent =>
      isProvider ? const Color(0xFF21C6AE) : const Color(0xFF43A7FF);

  Color get roleAccentStrong =>
      isProvider ? const Color(0xFF079A88) : const Color(0xFF167DE4);

  @override
  void initState() {
    super.initState();
    registerMode = widget.initialRegisterMode;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  Future<void> authenticate() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false) || loading) {
      return;
    }

    if (registerMode && !widget.isProvider && registrationPhotoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A profile photo is required to continue as a driver.'),
          backgroundColor: raDanger,
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    final service = authService;
    try {
      final role = widget.isProvider ? 'provider' : 'driver';

      if (registerMode) {
        await service
            .register(
              email: emailController.text,
              password: passwordController.text,
              role: role,
              displayName: nameController.text,
              phone: normalizeSriLankaPhone(phoneController.text),
            )
            .timeout(const Duration(seconds: 45));
      } else {
        await service.signIn(
          email: emailController.text,
          password: passwordController.text,
          role: role,
        );
      }

      if (registerMode && registrationPhotoData != null) {
        try {
          await service
              .updateCurrentProfile({'photoData': registrationPhotoData})
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          if (!widget.isProvider) {
            await service.signOut();
          }

          rethrow;
        }
      }

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'session-unavailable',
          message: 'Your sign-in session is unavailable. Please sign in again.',
        );
      }

      if (enforceEmailVerification &&
          !await service.isRoleEmailVerified(role)) {
        replace(context, EmailVerificationScreen(role: role));
        if (service.verificationEmailDeliveryFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account saved, but the verification email could not be sent. Please use Resend email.',
              ),
            ),
          );
        }
      } else {
        replace(
          context,
          widget.isProvider ? const ProviderShell() : const DriverShell(),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-credential' || 'user-not-found' || 'wrong-password' =>
          'Email or password is incorrect, or this account no longer exists.',
        'account-not-found' =>
          'This account no longer exists. Please create a new account.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'user-disabled' => 'This account has been disabled. Contact support.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' =>
          'Network unavailable. Check your internet connection.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this Firebase project.',
        'wrong-role' =>
          error.message ?? 'Sign in to the selected account role.',
        'role-auth-unavailable' =>
          'Account service is temporarily unavailable. Please try again.',
        'invalid-argument' => 'Check your account details and password.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } on TimeoutException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase is taking too long. Check internet and try Sign In; the account may already be created.',
          ),
          backgroundColor: raDanger,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to connect to Firebase. Please try again.'),
          backgroundColor: raDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  Future<void> chooseRegistrationPhoto() async {
    final navigator = Navigator.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
      preparingRegistrationPhoto = true;
    });

    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);

      if (mounted) {
        setState(() {
          registrationPhotoData = encoded;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to prepare photo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          preparingRegistrationPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> resetPassword() async {
    final controller = TextEditingController(text: emailController.text.trim());

    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        final dark = theme.brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0B1B29) : colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            roleAccent.withValues(alpha: .24),
                            roleAccentStrong.withValues(alpha: .14),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: roleAccent,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset ${widget.isProvider ? 'provider' : 'driver'} password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'We will send a secure reset link to your email.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              height: 1.45,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _PremiumField(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: controller.text.isEmpty,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'name@email.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (_) {
                      Navigator.pop(sheetContext, controller.text.trim());
                    },
                  ),
                ),

                const SizedBox(height: 18),

                _GradientAuthButton(
                  accent: roleAccent,
                  accentStrong: roleAccentStrong,
                  icon: Icons.forward_to_inbox_rounded,
                  label: 'Send reset link',
                  loading: false,
                  onPressed: () {
                    Navigator.pop(sheetContext, controller.text.trim());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (email == null || email.isEmpty || !mounted) {
      return;
    }

    final validation = validateEmailAddress(email);

    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation), backgroundColor: raDanger),
      );

      return;
    }

    try {
      await authService.sendPasswordResetEmail(
        email,
        role: widget.isProvider ? 'provider' : 'driver',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for this email, a password reset link will arrive shortly. Check Spam too.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to send reset email.'),
          backgroundColor: raDanger,
        ),
      );
    }
  }

  // ============================================================
  // PROFILE PHOTO UI
  // ============================================================

  Widget _photoSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      key: const Key('auth_profile_photo_section'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D2132) : const Color(0xFFF4F9FD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: registrationPhotoData != null
              ? roleAccent.withValues(alpha: .45)
              : colors.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: registrationPhotoData == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            roleAccent.withValues(alpha: .24),
                            roleAccentStrong.withValues(alpha: .12),
                          ],
                        )
                      : null,
                  border: Border.all(
                    color: roleAccent.withValues(alpha: .38),
                    width: 1.4,
                  ),
                ),
                child: ClipOval(
                  child: registrationPhotoData == null
                      ? Icon(
                          widget.isProvider
                              ? Icons.engineering_rounded
                              : Icons.person_rounded,
                          color: roleAccent,
                          size: 32,
                        )
                      : Image.memory(
                          base64Decode(registrationPhotoData!),
                          fit: BoxFit.cover,
                        ),
                ),
              ),

              Positioned(
                right: -4,
                bottom: -3,
                child: Material(
                  color: roleAccent,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: preparingRegistrationPhoto
                        ? null
                        : chooseRegistrationPhoto,
                    child: SizedBox(
                      width: 31,
                      height: 31,
                      child: Center(
                        child: preparingRegistrationPhoto
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.isProvider ? 'Profile photo' : 'Driver photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),

                    if (!widget.isProvider)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA52F).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Required',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFFA52F),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  registrationPhotoData == null
                      ? widget.isProvider
                            ? 'Optional now. You can add one later.'
                            : 'Add a clear photo before creating your account.'
                      : 'Photo ready. Tap the camera to change it.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 6),

                InkWell(
                  onTap: preparingRegistrationPhoto
                      ? null
                      : chooseRegistrationPhoto,
                  child: Text(
                    registrationPhotoData == null
                        ? 'Choose photo'
                        : 'Change photo',
                    style: GoogleFonts.plusJakartaSans(
                      color: roleAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return RaScaffold(
      backgroundColor: dark ? const Color(0xFF06121D) : const Color(0xFFF5F9FC),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _AuthBackdrop(dark: dark, accent: roleAccent),
            ),
          ),

          SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
              children: [
                _AuthTopBar(accent: roleAccent),

                const SizedBox(height: 27),

                _AuthHero(
                  isProvider: widget.isProvider,
                  registerMode: registerMode,
                  accent: roleAccent,
                  accentStrong: roleAccentStrong,
                ),

                const SizedBox(height: 25),

                _AuthModeSwitcher(
                  registerMode: registerMode,
                  loading: loading,
                  accent: roleAccent,
                  onSignIn: () {
                    setState(() {
                      registerMode = false;
                    });
                  },
                  onRegister: () {
                    setState(() {
                      registerMode = true;
                    });
                  },
                ),

                const SizedBox(height: 17),

                Container(
                  padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xE80B1A28)
                        : Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: .08)
                          : const Color(0xFFDDE9F2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .20 : .06),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      roleAccent.withValues(alpha: .25),
                                      roleAccentStrong.withValues(alpha: .10),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  registerMode
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.login_rounded,
                                  color: roleAccent,
                                  size: 22,
                                ),
                              ),

                              const SizedBox(width: 13),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      registerMode
                                          ? 'Create $roleName account'
                                          : '$roleName sign in',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.35,
                                        color: colors.onSurface,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      registerMode
                                          ? 'A few details and you are ready to go.'
                                          : 'Welcome back. Enter your account details.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        height: 1.4,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          if (registerMode) ...[
                            _photoSection(context),

                            const SizedBox(height: 21),

                            const _PremiumFieldLabel('FULL NAME'),

                            const SizedBox(height: 7),

                            _PremiumField(
                              child: TextFormField(
                                controller: nameController,
                                autofillHints: const [AutofillHints.name],
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Your full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                validator: (value) {
                                  final name = value?.trim() ?? '';

                                  if (name.isEmpty) {
                                    return 'Enter your full name';
                                  }

                                  if (name.length < 2) {
                                    return 'Name is too short';
                                  }
                                  if (name.length > 100) {
                                    return 'Use at most 100 characters';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            const _PremiumFieldLabel('PHONE NUMBER'),

                            const SizedBox(height: 7),

                            _PremiumField(
                              child: TextFormField(
                                controller: phoneController,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '+94 77 123 4567',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                validator: validateSriLankaPhone,
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],

                          const _PremiumFieldLabel('EMAIL ADDRESS'),

                          const SizedBox(height: 7),

                          _PremiumField(
                            child: TextFormField(
                              key: const Key('auth_email_field'),
                              controller: emailController,
                              autofillHints: const [AutofillHints.email],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'name@email.com',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              validator: validateEmailAddress,
                            ),
                          ),

                          const SizedBox(height: 16),

                          const _PremiumFieldLabel('PASSWORD'),

                          const SizedBox(height: 7),

                          _PremiumField(
                            child: TextFormField(
                              key: const Key('auth_password_field'),
                              controller: passwordController,
                              obscureText: obscure,
                              autofillHints: [
                                registerMode
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!loading) {
                                  authenticate();
                                }
                              },
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                suffixIcon: IconButton(
                                  tooltip: obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      obscure = !obscure;
                                    });
                                  },
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final password = value ?? '';

                                if (password.length < 6) {
                                  return 'Enter at least 6 characters';
                                }

                                if (registerMode && password.length < 8) {
                                  return 'New passwords need at least 8 characters';
                                }

                                if (registerMode &&
                                    (!RegExp(r'[A-Za-z]').hasMatch(password) ||
                                        !RegExp(r'\d').hasMatch(password))) {
                                  return 'Include at least one letter and one number';
                                }

                                return null;
                              },
                            ),
                          ),

                          if (registerMode) ...[
                            const SizedBox(height: 8),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),

                                const SizedBox(width: 6),

                                Expanded(
                                  child: Text(
                                    'Use 8+ characters with at least one letter and one number.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      height: 1.4,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (!registerMode) ...[
                            const SizedBox(height: 6),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const Key('auth_forgot_password'),
                                onPressed: loading ? null : resetPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor: roleAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 7,
                                  ),
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                          ] else
                            const SizedBox(height: 18),

                          _GradientAuthButton(
                            key: const Key('auth_submit_button'),
                            accent: roleAccent,
                            accentStrong: roleAccentStrong,
                            icon: registerMode
                                ? Icons.arrow_forward_rounded
                                : Icons.login_rounded,
                            label: loading
                                ? registerMode
                                      ? 'Creating accountâ€¦'
                                      : 'Signing inâ€¦'
                                : registerMode
                                ? 'Create $roleName Account'
                                : widget.isProvider
                                ? 'Continue to Provider Dashboard'
                                : 'Sign In as Driver',
                            loading: loading,
                            onPressed: loading ? null : authenticate,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                _AuthSecurityNote(
                  isProvider: widget.isProvider,
                  accent: roleAccent,
                ),

                if (!widget.isProvider) ...[
                  const SizedBox(height: 11),

                  _EmergencyGuestButton(
                    onTap: () {
                      replace(context, const DriverShell());
                    },
                  ),
                ],

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'RoadAssist â€¢ Sri Lanka',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.onSurfaceVariant.withValues(alpha: .65),
                      fontSize: 9.5,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w500,
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

// ============================================================
// RESPONSIVE TOP BAR
// ============================================================

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        final logoSize = compact ? 31.0 : 36.0;
        final brandFontSize = compact ? 14.5 : 17.0;
        final brandGap = compact ? 5.0 : 8.0;

        return Row(
          children: [
            SizedBox(
              width: compact ? 37 : 42,
              height: compact ? 37 : 42,
              child: canPop
                  ? _AuthCircleAction(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    )
                  : const SizedBox.shrink(),
            ),

            SizedBox(width: compact ? 4 : 8),

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WelcomeBrandLogo(size: logoSize),

                  SizedBox(width: brandGap),

                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Road',
                              style: TextStyle(color: colors.onSurface),
                            ),
                            TextSpan(
                              text: 'Assist',
                              style: TextStyle(color: accent),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: brandFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: compact ? 4 : 8),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: const _WelcomeThemeToggle(),
            ),
          ],
        );
      },
    );
  }
}

class _AuthCircleAction extends StatelessWidget {
  const _AuthCircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? Colors.white.withValues(alpha: .055) : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.expand(child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.isProvider,
    required this.registerMode,
    required this.accent,
    required this.accentStrong,
  });

  final bool isProvider;
  final bool registerMode;
  final Color accent;
  final Color accentStrong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final title = registerMode
        ? isProvider
              ? 'Grow your roadside\nservice business.'
              : 'Roadside help starts\nwith your account.'
        : isProvider
        ? 'Welcome back,\nservice professional.'
        : 'Get back on the road\nwith confidence.';

    final body = registerMode
        ? isProvider
              ? 'Create your provider profile, complete verification and start receiving eligible assistance requests.'
              : 'Save your vehicles, request roadside help, compare provider quotes and follow every job live.'
        : isProvider
        ? 'Manage requests, quotes, active jobs, earnings and customer conversations from one place.'
        : 'Access your vehicles, assistance requests, messages, invoices and roadside history.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: .20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProvider
                    ? Icons.engineering_rounded
                    : Icons.directions_car_rounded,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                '${isProvider ? 'PROVIDER' : 'DRIVER'} ACCESS',
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            height: 1.10,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          body,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.58,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AuthMiniBadge(
              icon: Icons.verified_user_outlined,
              text: isProvider ? 'Verified professionals' : 'Secure assistance',
              accent: accent,
            ),
            _AuthMiniBadge(
              icon: Icons.location_on_outlined,
              text: 'Sri Lanka',
              accent: accentStrong,
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// RESPONSIVE MINI BADGE
// ============================================================

class _AuthMiniBadge extends StatelessWidget {
  const _AuthMiniBadge({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: accent),
          ),

          const SizedBox(width: 5),

          Flexible(
            child: Text(
              text,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODE SWITCH
// ============================================================

class _AuthModeSwitcher extends StatelessWidget {
  const _AuthModeSwitcher({
    required this.registerMode,
    required this.loading,
    required this.accent,
    required this.onSignIn,
    required this.onRegister,
  });

  final bool registerMode;
  final bool loading;
  final Color accent;

  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .05)
            : const Color(0xFFE9F1F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              key: const Key('auth_sign_in_tab'),
              label: 'Sign In',
              selected: !registerMode,
              accent: accent,
              onTap: loading ? null : onSignIn,
            ),
          ),

          Expanded(
            child: _AuthModeButton(
              key: const Key('auth_create_account_tab'),
              label: 'Create Account',
              selected: registerMode,
              accent: accent,
              onTap: loading ? null : onRegister,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? dark
                  ? const Color(0xFF13283A)
                  : Colors.white
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .15 : .05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM INPUT FIELD
// ============================================================

class _PremiumField extends StatelessWidget {
  const _PremiumField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .045)
            : const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .50)),
      ),
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _PremiumFieldLabel extends StatelessWidget {
  const _PremiumFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 9,
        letterSpacing: 1.05,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ============================================================
// GRADIENT AUTH BUTTON
// ============================================================

class _GradientAuthButton extends StatelessWidget {
  const _GradientAuthButton({
    super.key,
    required this.accent,
    required this.accentStrong,
    required this.icon,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final Color accent;
  final Color accentStrong;

  final IconData icon;
  final String label;

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: disabled ? .55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accent, accentStrong],
            ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: .23),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 19, color: Colors.white),

                  const SizedBox(width: 9),

                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECURITY / VERIFICATION NOTE
// ============================================================

class _AuthSecurityNote extends StatelessWidget {
  const _AuthSecurityNote({required this.isProvider, required this.accent});

  final bool isProvider;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .035)
            : Colors.white.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isProvider ? Icons.verified_user_outlined : Icons.shield_outlined,
              color: accent,
              size: 18,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              isProvider
                  ? 'Provider accounts require verification before roadside jobs become available.'
                  : 'Your RoadAssist account keeps vehicles, requests, messages and assistance history together.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.8,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMERGENCY GUEST BUTTON
// ============================================================

class _EmergencyGuestButton extends StatelessWidget {
  const _EmergencyGuestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA62B).withValues(alpha: .075),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFFFA62B).withValues(alpha: .20),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.emergency_outlined,
                color: Color(0xFFFFA62B),
                size: 19,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Need urgent help? Continue as guest',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),

              Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND DECORATION
// ============================================================

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.dark, required this.accent});

  final bool dark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -130,
          right: -100,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: dark ? .13 : .10),
                  accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: -130,
          top: 390,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3978FF).withValues(alpha: dark ? .08 : .055),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
