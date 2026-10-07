part of '../../screens.dart';

class _AuthForm extends StatefulWidget {
  const _AuthForm({
    required this.isProvider,
    this.initialRegisterMode = false,
  });

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

  Future<void> authenticate() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false) || loading) {
      return;
    }

    if (registerMode &&
        !widget.isProvider &&
        registrationPhotoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A profile photo is required to continue as a driver.',
          ),
          backgroundColor: raDanger,
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final role = widget.isProvider ? 'provider' : 'driver';

      if (registerMode) {
        await authService
            .register(
              email: emailController.text,
              password: passwordController.text,
              role: role,
              displayName: nameController.text,
              phone: normalizeSriLankaPhone(
                phoneController.text,
              ),
            )
            .timeout(
              const Duration(seconds: 45),
            );
      } else {
        await authService
            .signIn(
              email: emailController.text,
              password: passwordController.text,
              role: role,
            )
            .timeout(
              const Duration(seconds: 30),
            );
      }

      if (registerMode && registrationPhotoData != null) {
        try {
          await authService
              .updateCurrentProfile({
                'photoData': registrationPhotoData,
              })
              .timeout(
                const Duration(seconds: 15),
              );
        } catch (_) {
          if (!widget.isProvider) {
            await authService.signOut();
          }

          rethrow;
        }
      }

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (registerMode &&
          enforceEmailVerification &&
          user != null &&
          !user.emailVerified) {
        replace(
          context,
          EmailVerificationScreen(
            role: role,
          ),
        );
      } else {
        replace(
          context,
          widget.isProvider
              ? const ProviderShell()
              : const DriverShell(),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'email-already-in-use' =>
          'An account already exists for this email.',
        'invalid-credential' =>
          'Incorrect email or password.',
        'invalid-email' =>
          'Enter a valid email address.',
        'weak-password' =>
          'Use a password with at least 6 characters.',
        'user-disabled' =>
          'This account has been disabled. Contact support.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' =>
          'Network unavailable. Check your internet connection.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this Firebase project.',
        'wrong-role' =>
          error.message ??
              'This account has a different role.',
        _ =>
          error.message ??
              'Authentication failed. Please try again.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: raDanger,
        ),
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
          content: Text(
            'Unable to connect to Firebase. Please try again.',
          ),
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

  Future<void> chooseRegistrationPhoto() async {
    final navigator = Navigator.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return const SafeArea(
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
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final photo = source == ImageSource.camera
        ? await navigator.push<XFile>(
            MaterialPageRoute(
              builder: (_) => const CameraCaptureScreen(),
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
      preparingRegistrationPhoto = true;
    });

    try {
      final encoded =
          await PhotoUploadService().prepareProfilePhoto(photo);

      if (mounted) {
        setState(() {
          registrationPhotoData = encoded;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to prepare photo: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          preparingRegistrationPhoto = false;
        });
      }
    }
  }

  Future<void> resetPassword() async {
    final controller = TextEditingController(
      text: emailController.text.trim(),
    );

    final email = await showModalBottomSheet<String>(
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
            MediaQuery.of(sheetContext).viewInsets.bottom +
                RaSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.lock_reset_outlined,
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset password',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'We will send a secure reset link to your email.',
                          style: Theme.of(
                            sheetContext,
                          ).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.lg),
              TextField(
                controller: controller,
                keyboardType:
                    TextInputType.emailAddress,
                autofocus: controller.text.isEmpty,
                textInputAction:
                    TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                ),
                onSubmitted: (_) {
                  Navigator.pop(
                    sheetContext,
                    controller.text.trim(),
                  );
                },
              ),
              const SizedBox(height: RaSpace.lg),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  controller.text.trim(),
                ),
                icon: const Icon(
                  Icons.forward_to_inbox_outlined,
                ),
                label: const Text(
                  'Send Reset Link',
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (email == null ||
        email.isEmpty ||
        !mounted) {
      return;
    }

    final validation =
        validateEmailAddress(email);

    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: raDanger,
        ),
      );

      return;
    }

    try {
      await authService
          .sendPasswordResetEmail(email);

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
          content: Text(
            error.message ??
                'Unable to send reset email.',
          ),
          backgroundColor: raDanger,
        ),
      );
    }
  }

  Widget _photoSection(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.lg,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: .34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: .52),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              registrationPhotoData == null
                  ? Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color:
                            colors.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(23),
                      ),
                      child: Icon(
                        widget.isProvider
                            ? Icons
                                .engineering_outlined
                            : Icons
                                .person_outline_rounded,
                        color: colors
                            .onPrimaryContainer,
                        size: 31,
                      ),
                    )
                  : ClipRRect(
                      borderRadius:
                          BorderRadius.circular(23),
                      child: Image.memory(
                        base64Decode(
                          registrationPhotoData!,
                        ),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
              Positioned(
                right: -7,
                bottom: -7,
                child: IconButton.filled(
                  tooltip:
                      'Choose profile photo',
                  onPressed:
                      preparingRegistrationPhoto
                      ? null
                      : chooseRegistrationPhoto,
                  icon:
                      preparingRegistrationPhoto
                      ? const SizedBox.square(
                          dimension: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          size: 17,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(width: RaSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isProvider
                      ? 'Profile photo'
                      : 'Driver profile photo',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  registrationPhotoData == null
                      ? widget.isProvider
                          ? 'Optional during provider account creation.'
                          : 'Required when creating a driver account.'
                      : 'Photo added. You can change it before creating the account.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                TextButton(
                  onPressed:
                      preparingRegistrationPhoto
                      ? null
                      : chooseRegistrationPhoto,
                  child: Text(
                    registrationPhotoData == null
                        ? 'Choose Photo'
                        : 'Change Photo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleHero(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final role =
        widget.isProvider ? 'Provider' : 'Driver';

    return Container(
      padding: const EdgeInsets.all(
        RaSpace.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            const Color(0xFF007D70),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -25,
            child: Icon(
              widget.isProvider
                  ? Icons
                      .home_repair_service_outlined
                  : Icons
                      .directions_car_outlined,
              size: 130,
              color:
                  Colors.white.withValues(
                alpha: .07,
              ),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(999),
                ),
                child: Text(
                  '$role Account'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              const SizedBox(
                height: RaSpace.lg,
              ),
              Text(
                registerMode
                    ? widget.isProvider
                        ? 'Join RoadAssist as a service professional.'
                        : 'Create your RoadAssist driver account.'
                    : widget.isProvider
                        ? 'Welcome back, service professional.'
                        : 'Welcome back to RoadAssist.',
                style: theme
                    .textTheme.headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.isProvider
                    ? registerMode
                        ? 'Create your account, verify your email and continue to provider verification before jobs unlock.'
                        : 'Sign in to manage verification, requests, active jobs and services.'
                    : registerMode
                        ? 'Save vehicles, request help, compare quotes and follow assistance live.'
                        : 'Access your saved vehicles, requests, messages and roadside support.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color:
                      Colors.white.withValues(
                    alpha: .84,
                  ),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final role =
        widget.isProvider ? 'Provider' : 'Driver';

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading:
            Navigator.of(context).canPop()
            ? const BackButton()
            : null,
        title: Text(
          '$role account',
        ),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding:
              const EdgeInsets.fromLTRB(
            RaSpace.lg,
            RaSpace.sm,
            RaSpace.lg,
            RaSpace.xxxl,
          ),
          children: [
            const _AuthWordmark(),

            const SizedBox(height: RaSpace.lg),

            _roleHero(context),

            const SizedBox(height: RaSpace.lg),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors
                    .surfaceContainerHighest
                    .withValues(alpha: .50),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AuthModeButton(
                      label: 'Sign In',
                      selected: !registerMode,
                      onTap: loading
                          ? null
                          : () {
                              setState(() {
                                registerMode = false;
                              });
                            },
                    ),
                  ),
                  Expanded(
                    child: _AuthModeButton(
                      label: 'Create Account',
                      selected: registerMode,
                      onTap: loading
                          ? null
                          : () {
                              setState(() {
                                registerMode = true;
                              });
                            },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: RaSpace.lg),

            Container(
              padding: const EdgeInsets.all(
                RaSpace.lg,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius:
                    BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant
                      .withValues(alpha: .6),
                ),
              ),
              child: Form(
                key: formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  colors.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(
                                13,
                              ),
                            ),
                            child: Icon(
                              registerMode
                                  ? Icons
                                      .person_add_alt_1_outlined
                                  : Icons
                                      .login_rounded,
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
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  registerMode
                                      ? 'Create $role Account'
                                      : '$role Sign In',
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
                                  registerMode
                                      ? 'Enter your details to continue.'
                                      : 'Enter your account credentials.',
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

                      if (registerMode) ...[
                        _photoSection(context),

                        const SizedBox(
                          height: RaSpace.lg,
                        ),

                        const FieldLabel(
                          'FULL NAME',
                        ),

                        TextFormField(
                          controller:
                              nameController,
                          autofillHints: const [
                            AutofillHints.name,
                          ],
                          textCapitalization:
                              TextCapitalization
                                  .words,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            hintText:
                                'Your full name',
                            prefixIcon: Icon(
                              Icons
                                  .person_outline_rounded,
                            ),
                          ),
                          validator: (value) {
                            final name =
                                value?.trim() ??
                                    '';

                            if (name.isEmpty) {
                              return 'Enter your full name';
                            }

                            if (name.length < 2) {
                              return 'Name is too short';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const FieldLabel(
                          'PHONE NUMBER',
                        ),

                        TextFormField(
                          controller:
                              phoneController,
                          autofillHints: const [
                            AutofillHints
                                .telephoneNumber,
                          ],
                          keyboardType:
                              TextInputType.phone,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            hintText:
                                '+94 77 123 4567',
                            prefixIcon: Icon(
                              Icons
                                  .phone_outlined,
                            ),
                          ),
                          validator:
                              validateSriLankaPhone,
                        ),

                        const SizedBox(height: 16),
                      ],

                      const FieldLabel(
                        'EMAIL ADDRESS',
                      ),

                      TextFormField(
                        controller:
                            emailController,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          hintText:
                              'name@email.com',
                          prefixIcon: Icon(
                            Icons
                                .email_outlined,
                          ),
                        ),
                        validator:
                            validateEmailAddress,
                      ),

                      const SizedBox(height: 16),

                      const FieldLabel(
                        'PASSWORD',
                      ),

                      TextFormField(
                        controller:
                            passwordController,
                        obscureText: obscure,
                        autofillHints: [
                          registerMode
                              ? AutofillHints
                                  .newPassword
                              : AutofillHints
                                  .password,
                        ],
                        textInputAction:
                            TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!loading) {
                            authenticate();
                          }
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Enter your password',
                          helperText: registerMode
                              ? '8+ characters with at least one letter and one number'
                              : null,
                          prefixIcon:
                              const Icon(
                            Icons
                                .lock_outline_rounded,
                          ),
                          suffixIcon:
                              IconButton(
                            tooltip: obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                obscure =
                                    !obscure;
                              });
                            },
                            icon: Icon(
                              obscure
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password =
                              value ?? '';

                          if (password.length <
                              6) {
                            return 'Enter at least 6 characters';
                          }

                          if (registerMode &&
                              password.length <
                                  8) {
                            return 'New passwords need at least 8 characters';
                          }

                          if (registerMode &&
                              (!RegExp(
                                r'[A-Za-z]',
                              ).hasMatch(
                                password,
                              ) ||
                                  !RegExp(
                                    r'\d',
                                  ).hasMatch(
                                    password,
                                  ))) {
                            return 'Include at least one letter and one number';
                          }

                          return null;
                        },
                      ),

                      if (!registerMode)
                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : resetPassword,
                            child: const Text(
                              'Forgot password?',
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: RaSpace.lg,
                      ),

                      FilledButton.icon(
                        onPressed: loading
                            ? null
                            : authenticate,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                registerMode
                                    ? Icons
                                        .person_add_alt_1_rounded
                                    : Icons
                                        .login_rounded,
                              ),
                        label: Text(
                          loading
                              ? registerMode
                                  ? 'Creating account…'
                                  : 'Signing in…'
                              : registerMode
                                  ? 'Create $role Account'
                                  : widget.isProvider
                                      ? 'Login to Provider Dashboard'
                                      : 'Login as Driver',
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: RaSpace.md),

            Container(
              padding: const EdgeInsets.all(
                RaSpace.md,
              ),
              decoration: BoxDecoration(
                color: colors
                    .surfaceContainerHighest
                    .withValues(alpha: .34),
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.isProvider
                        ? Icons
                            .verified_user_outlined
                        : Icons
                            .shield_outlined,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(
                    width: RaSpace.sm,
                  ),
                  Expanded(
                    child: Text(
                      widget.isProvider
                          ? 'Provider accounts require verification before roadside jobs become available.'
                          : 'Your account keeps saved vehicles, requests, conversations and roadside assistance history together.',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!widget.isProvider) ...[
              const SizedBox(
                height: RaSpace.sm,
              ),
              TextButton.icon(
                onPressed: () => replace(
                  context,
                  const DriverShell(),
                ),
                icon: const Icon(
                  Icons.emergency_outlined,
                ),
                label: const Text(
                  'Continue as Guest for Emergency',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected
          ? colors.surface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(
              color: selected
                  ? colors.primary
                  : colors.onSurfaceVariant,
              fontWeight: selected
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}