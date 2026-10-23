part of '../../screens.dart';

class _AuthForm extends StatefulWidget {
  const _AuthForm({
    required this.isProvider,
    this.initialRegisterMode = false,
    this.commonLogin = false,
  });

  final bool isProvider;
  final bool initialRegisterMode;
  final bool commonLogin;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  late bool registerMode;

  final journey = AuthJourneyController();
  final authScroll = ScrollController();
  void beginAuthMotion() {
    FocusScope.of(context).unfocus();
    journey.update(phase: AuthJourneyPhase.authenticating);
    if (authScroll.hasClients) {
      final reduced =
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context);
      if (reduced) {
        authScroll.jumpTo(0);
      } else {
        unawaited(
          authScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  final passwordFocus = FocusNode();
  final emailFocus = FocusNode();

  void updateJourney() {
    if (loading || journey.phase == AuthJourneyPhase.success) return;
    final completed =
        [
          nameController.text.trim().length >= 2,
          validateEmailAddress(emailController.text) == null,
          passwordController.text.length >= 8,
        ].where((x) => x).length /
        3;
    journey.update(
      phase: passwordFocus.hasFocus
          ? AuthJourneyPhase.password
          : emailFocus.hasFocus
          ? AuthJourneyPhase.typing
          : AuthJourneyPhase.idle,
      progress: registerMode ? completed : 0,
      privacy: obscure,
    );
  }

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

  late bool selectedProvider;
  bool get isProvider => selectedProvider;
  bool get commonLogin => widget.commonLogin && !registerMode;

  String get roleName => isProvider ? 'Provider' : 'Driver';

  Color get roleAccent => const Color(0xFF43A7FF);

  Color get roleAccentStrong => const Color(0xFF167DE4);

  @override
  void initState() {
    super.initState();
    registerMode = widget.initialRegisterMode;
    selectedProvider = widget.isProvider;
    passwordFocus.addListener(updateJourney);
    emailFocus.addListener(updateJourney);
    for (final field in [nameController, emailController, passwordController]) {
      field.addListener(updateJourney);
    }
  }

  @override
  void dispose() {
    passwordFocus.dispose();
    emailFocus.dispose();
    journey.dispose();
    authScroll.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  Future<void> authenticateGoogle() async {
    if (loading) return;
    var role = commonLogin
        ? 'auto'
        : isProvider
        ? 'provider'
        : 'driver';
    if (registerMode &&
        (nameController.text.trim().length < 2 ||
            !RegExp(
              r'^\+947\d{8}$',
            ).hasMatch(normalizeSriLankaPhone(phoneController.text)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your name and valid phone number first. A photo is optional; no password is needed for Google.',
          ),
        ),
      );
      return;
    }
    setState(() => loading = true);
    beginAuthMotion();
    try {
      await authService.signInWithGoogle(
        role: role,
        chooseRole: chooseExistingAccount,
        displayName: registerMode ? nameController.text.trim() : null,
        phone: registerMode
            ? normalizeSriLankaPhone(phoneController.text)
            : null,
        photoData: registerMode ? registrationPhotoData : null,
      );
      if (!mounted) return;
      final profile = await authService.getCurrentProfile();
      role = accountLastRole(profile.data()) ?? role;
      if (!mounted) return;
      await journey.complete();
      if (!mounted) return;
      final verified =
          !enforceEmailVerification ||
          await authService.isRoleEmailVerified(role);
      if (!mounted) return;
      replace(
        context,
        !verified
            ? EmailVerificationScreen(role: role)
            : role == 'provider'
            ? const ProviderShell()
            : const DriverShell(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if ([
        'popup-closed-by-user',
        'cancelled-popup-request',
        'canceled',
      ].contains(e.code))
        return;
      final message = switch (e.code) {
        'google-web-only' =>
          'Google login is currently available in the web app.',
        'profile-details-required' =>
          'Choose Create Account and complete your profile, then continue with Google.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled yet. Please use email sign-in.',
        'user-disabled' => 'This account has been disabled. Contact support.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'popup-blocked' =>
          'Allow sign-in popups in your browser and try again.',
        'unauthorized-domain' =>
          'Google sign-in is not configured for this app domain yet.',
        _ => 'Unable to sign in with Google. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to connect. Please try Google sign-in again.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => loading = false);
        if (journey.phase != AuthJourneyPhase.success) updateJourney();
      }
    }
  }

  Future<void> authenticate() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false) || loading) {
      return;
    }

    setState(() {
      loading = true;
    });
    beginAuthMotion();

    final service = authService;
    try {
      var role = isProvider ? 'provider' : 'driver';

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
      } else if (commonLogin) {
        role = await service.signInCommon(
          email: emailController.text,
          password: passwordController.text,
          chooseRole: chooseExistingAccount,
        );
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
          if (!isProvider) {
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

      final verified =
          !enforceEmailVerification || await service.isRoleEmailVerified(role);
      if (!mounted) return;
      await journey.complete();
      if (!mounted) return;
      if (!verified) {
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
          role == 'provider' ? const ProviderShell() : const DriverShell(),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted || error.code == 'canceled') return;

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
        if (journey.phase != AuthJourneyPhase.success) updateJourney();
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
    final resetRole = commonLogin
        ? await pickAccountRole('Which password do you want to reset?')
        : isProvider
        ? 'provider'
        : 'driver';
    if (resetRole == null || !mounted) return;
    var resetEmail = emailController.text.trim();

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
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              decoration: RaPremiumDecoration(
                context,
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
                              'Reset $resetRole password',
                              style: roadAssistTextStyle(
                                fontSize: 20,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We will send a secure reset link to your email.',
                              style: roadAssistTextStyle(
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
                    child: TextFormField(
                      initialValue: resetEmail,
                      onChanged: (value) => resetEmail = value,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: resetEmail.isEmpty,
                      textInputAction: TextInputAction.done,
                      style: roadAssistTextStyle(fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'name@email.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onFieldSubmitted: (_) {
                        Navigator.pop(sheetContext, resetEmail.trim());
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
                      Navigator.pop(sheetContext, resetEmail.trim());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

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
      await authService.sendPasswordResetEmail(email, role: resetRole);

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
                          isProvider
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
                      isProvider ? 'Profile photo' : 'Driver photo',
                      style: roadAssistTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),

                    if (!isProvider)
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
                          'Optional',
                          style: roadAssistTextStyle(
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
                      ? isProvider
                            ? 'Optional now. You can add one later.'
                            : 'Optional now. You can add one later.'
                      : 'Photo ready. Tap the camera to change it.',
                  style: roadAssistTextStyle(
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
                    style: roadAssistTextStyle(
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

  Future<String?> pickAccountRole(
    String title, {
    List<String> roles = const ['driver', 'provider'],
  }) {
    if (!mounted) return Future.value(null);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: roadAssistTextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Separate profiles. One trusted platform.',
              style: roadAssistTextStyle(
                fontSize: 12,
                color: Theme.of(sheet).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (final role in roles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.pop(sheet, role),
                  child: Row(
                    children: [
                      if (role == 'driver')
                        Image.asset(
                          'assets/images/auth_journey_car.png',
                          width: 92,
                          height: 48,
                        )
                      else
                        const SizedBox(
                          width: 92,
                          height: 48,
                          child: Icon(Icons.engineering_rounded, size: 40),
                        ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role == 'driver'
                                  ? "I'm a driver"
                                  : 'I provide help',
                              style: roadAssistTextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              role == 'driver'
                                  ? 'Help for every journey.'
                                  : 'Bring your expertise to the road.',
                              style: roadAssistTextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> chooseExistingAccount(List<String> roles) =>
      pickAccountRole('Choose your account', roles: roles);

  Future<void> beginRegistration() async {
    if (loading) return;
    final role = await pickAccountRole('How will you use RoadAssist?');
    if (role == null || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      selectedProvider = role == 'provider';
      registerMode = true;
    });
    journey.update(phase: AuthJourneyPhase.idle, progress: 0);
    if (authScroll.hasClients) authScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return RaScaffold(
      backgroundColor: dark ? const Color(0xFF041426) : const Color(0xFFF7FBFF),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _AuthBackdrop(dark: dark, accent: roleAccent),
            ),
          ),
          SafeArea(
            child: ListView(
              controller: authScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              children: [
                _AuthTopBar(accent: roleAccent),
                const SizedBox(height: 12),
                AuthJourneyScene(
                  controller: journey,
                  registration: registerMode,
                  provider: registerMode && isProvider,
                ),
                const SizedBox(height: 12),
                Text(
                  registerMode
                      ? isProvider
                            ? 'Bring your skills\nto the road.'
                            : 'Your journey.\nA better beginning.'
                      : 'Good to see you.',
                  style: roadAssistTextStyle(
                    fontSize: 30,
                    height: 1.10,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  registerMode
                      ? isProvider
                            ? 'Connect with drivers who need your help.'
                            : 'Create your own space for the road ahead.'
                      : 'Sign in and pick up where you left off.',
                  style: roadAssistTextStyle(
                    fontSize: 13,
                    height: 1.58,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Form(
                  key: formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                              style: roadAssistTextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Your full name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
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
                              style: roadAssistTextStyle(
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
                            focusNode: emailFocus,
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: roadAssistTextStyle(
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
                            focusNode: passwordFocus,
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
                            style: roadAssistTextStyle(
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
                                  updateJourney();
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
                                  style: roadAssistTextStyle(
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
                                style: roadAssistTextStyle(
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
                          icon: Icons.arrow_forward_rounded,
                          label: loading
                              ? (registerMode
                                    ? 'Creating account...'
                                    : 'Signing in...')
                              : registerMode
                              ? 'Create $roleName Account'
                              : 'Sign in',
                          loading: loading,
                          onPressed: loading ? null : authenticate,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'or continue with',
                                style: roadAssistTextStyle(
                                  fontSize: 10,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          key: const Key('auth_google_button'),
                          onPressed: loading ? null : authenticateGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F7FB),
                            foregroundColor: const Color(0xFF203342),
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Image.asset(
                            'assets/images/google_g.png',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : registerMode
                                ? () {
                                    setState(() => registerMode = false);
                                    updateJourney();
                                  }
                                : beginRegistration,
                            child: Text(
                              registerMode
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create account',
                            ),
                          ),
                        ),
                        if (registerMode)
                          Center(
                            child: TextButton(
                              onPressed: loading ? null : beginRegistration,
                              child: const Text('Change account type'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  registerMode
                      ? isProvider
                            ? 'Verify your email, then submit documents for admin review.'
                            : 'Email verification is required before your first journey.'
                      : 'Your account. Your journey. Securely connected.',
                  textAlign: TextAlign.center,
                  style: roadAssistTextStyle(
                    fontSize: 10,
                    height: 1.6,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (!registerMode) ...[
                  const SizedBox(height: 16),
                  _EmergencyGuestButton(
                    onTap: () => replace(context, const DriverShell()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                        style: roadAssistTextStyle(
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
      style: roadAssistTextStyle(
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
              colors: [const Color(0xFFA2E0FF), accent],
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF092940),
                      ),
                    ),
                  if (loading) const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.left,
                      style: roadAssistTextStyle(
                        color: const Color(0xFF092940),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.15,
                      ),
                    ),
                  ),
                  if (!loading)
                    Icon(icon, size: 19, color: const Color(0xFF092940)),
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
                  style: roadAssistTextStyle(
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
