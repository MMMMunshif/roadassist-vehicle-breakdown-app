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
  bool obscure = true, loading = false;

  @override
  void initState() {
    super.initState();
    registerMode = widget.initialRegisterMode;
  }

  String? registrationPhotoData;
  bool preparingRegistrationPhoto = false;
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  AuthService get authService => AuthService();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> authenticate() async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false) || loading) return;
    if (registerMode && !widget.isProvider && registrationPhotoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A profile photo is required to continue as a driver.'),
          backgroundColor: raDanger,
        ),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final role = widget.isProvider ? 'provider' : 'driver';
      if (registerMode) {
        await authService
            .register(
              email: emailController.text,
              password: passwordController.text,
              role: role,
              displayName: nameController.text,
              phone: normalizeSriLankaPhone(phoneController.text),
            )
            .timeout(const Duration(seconds: 45));
      } else {
        await authService
            .signIn(
              email: emailController.text,
              password: passwordController.text,
              role: role,
            )
            .timeout(const Duration(seconds: 30));
      }
      if (registerMode && registrationPhotoData != null) {
        try {
          await authService
              .updateCurrentProfile({'photoData': registrationPhotoData})
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          if (!widget.isProvider) await authService.signOut();
          rethrow;
        }
      }
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (registerMode &&
          enforceEmailVerification &&
          user != null &&
          !user.emailVerified) {
        replace(context, EmailVerificationScreen(role: role));
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
        'invalid-credential' => 'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'user-disabled' => 'This account has been disabled. Contact support.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' =>
          'Network unavailable. Check your internet connection.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this Firebase project.',
        'wrong-role' => error.message ?? 'This account has a different role.',
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
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseRegistrationPhoto() async {
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
    setState(() => preparingRegistrationPhoto = true);
    try {
      final encoded = await PhotoUploadService().prepareProfilePhoto(photo);
      if (mounted) setState(() => registrationPhotoData = encoded);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to prepare photo: $error')),
        );
    } finally {
      if (mounted) setState(() => preparingRegistrationPhoto = false);
    }
  }

  Future<void> resetPassword() async {
    final controller = TextEditingController(text: emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: controller.text.isEmpty,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    final validation = validateEmailAddress(email);
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation), backgroundColor: raDanger),
      );
      return;
    }
    try {
      await authService.sendPasswordResetEmail(email);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          Stack(
            children: [
              const AssetSlot(
                height: 210,
                label: 'LOGIN HERO IMAGE\nTow truck + mechanic + car',
                icon: Icons.car_repair,
                assetPath: 'assets/images/login_rescue.jpg',
              ),
              Positioned(
                left: RaSpace.md,
                top: RaSpace.md,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xl,
                RaSpace.xxl,
                RaSpace.xl,
                RaSpace.xxl,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      registerMode
                          ? widget.isProvider
                                ? 'Create Provider Account'
                                : 'Create Driver Account'
                          : widget.isProvider
                          ? 'Provider Sign In'
                          : 'Driver Sign In',
                      textAlign: TextAlign.center,
                      style: RaText.headline,
                    ),
                    const SizedBox(height: RaSpace.xs),
                    Text(
                      widget.isProvider
                          ? registerMode
                                ? 'Create account, verify email, then submit NIC and service documents. Admin approval is required before jobs unlock.'
                                : 'Sign in to view verification status or manage approved services'
                          : 'Access emergency assistance and live tracking',
                      textAlign: TextAlign.center,
                      style: RaText.bodyMuted,
                    ),
                    const SizedBox(height: RaSpace.xl),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign In')),
                        ButtonSegment(
                          value: true,
                          label: Text('Create Account'),
                        ),
                      ],
                      selected: {registerMode},
                      onSelectionChanged: (v) =>
                          setState(() => registerMode = v.first),
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: raBlue,
                        selectedForegroundColor: Colors.white,
                        side: const BorderSide(color: raLine),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: RaSpace.xl),
                    if (registerMode) ...[
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                registrationPhotoData == null
                                    ? const CircleAvatar(
                                        radius: 42,
                                        backgroundColor: raPale,
                                        child: Icon(
                                          Icons.person_outline,
                                          color: raBlue,
                                          size: 34,
                                        ),
                                      )
                                    : ClipOval(
                                        child: Image.memory(
                                          base64Decode(registrationPhotoData!),
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: IconButton.filled(
                                    tooltip: 'Add profile photo',
                                    onPressed: preparingRegistrationPhoto
                                        ? null
                                        : chooseRegistrationPhoto,
                                    icon: preparingRegistrationPhoto
                                        ? const SizedBox(
                                            width: 17,
                                            height: 17,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: preparingRegistrationPhoto
                                  ? null
                                  : chooseRegistrationPhoto,
                              child: Text(
                                registrationPhotoData == null
                                    ? widget.isProvider
                                          ? 'Add profile photo'
                                          : 'Add profile photo (required)'
                                    : 'Change profile photo',
                              ),
                            ),
                            if (!widget.isProvider &&
                                registrationPhotoData == null)
                              Text(
                                'Required when creating a driver account',
                                style: RaText.caption.copyWith(
                                  color: raDanger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: RaSpace.sm),
                    ],
                    if (registerMode) ...[
                      const FieldLabel('FULL NAME'),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Your full name',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Enter your full name';
                          if (name.length < 2) return 'Name is too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: RaSpace.md),
                      const FieldLabel('PHONE NUMBER'),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '+94 77 123 4567',
                        ),
                        validator: validateSriLankaPhone,
                      ),
                      const SizedBox(height: RaSpace.md),
                    ],
                    const FieldLabel('EMAIL ADDRESS'),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'name@email.com',
                      ),
                      validator: validateEmailAddress,
                    ),
                    const SizedBox(height: RaSpace.md),
                    const FieldLabel('PASSWORD'),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Enter your password',
                        suffixIcon: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: raMuted,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
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
                    const SizedBox(height: RaSpace.xl),
                    Container(
                      padding: const EdgeInsets.all(RaSpace.md),
                      decoration: BoxDecoration(
                        color: raPale,
                        borderRadius: BorderRadius.circular(RaRadius.sm),
                      ),
                      child: Row(
                        children: [
                          IconBadge(
                            widget.isProvider
                                ? Icons.verified_user_outlined
                                : Icons.shield_outlined,
                            size: 34,
                            background: Colors.white,
                          ),
                          const SizedBox(width: RaSpace.sm),
                          Expanded(
                            child: Text(
                              widget.isProvider
                                  ? 'Service Provider Account'
                                  : 'Driver Account',
                              style: RaText.label.copyWith(color: raNavy),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RaSpace.lg),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: raBlue.withValues(alpha: 0.8),
                        disabledForegroundColor: Colors.white,
                      ),
                      onPressed: loading ? null : authenticate,
                      child: loading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: RaSpace.md),
                                Text(
                                  registerMode
                                      ? 'Creating account…'
                                      : 'Signing in…',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              registerMode
                                  ? 'Create ${widget.isProvider ? 'Provider' : 'Driver'} Account'
                                  : widget.isProvider
                                  ? 'Login to Provider Dashboard'
                                  : 'Login as Driver',
                            ),
                    ),
                    if (!registerMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: loading ? null : resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    const SizedBox(height: RaSpace.md),
                    if (!widget.isProvider)
                      TextButton(
                        onPressed: () => replace(context, const DriverShell()),
                        child: const Text('Continue as Guest for Emergency'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// ACCOUNT SECURITY
// ============================================================
