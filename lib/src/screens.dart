import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'app.dart';
import 'models/request_draft.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/request_service.dart';
import 'services/photo_upload_service.dart';
import 'services/route_service.dart';

part 'features/request/assistance_type_screen.dart';

bool get firebaseReady => Firebase.apps.isNotEmpty;
bool get signedIn => firebaseReady && FirebaseAuth.instance.currentUser != null;

// Email actions are delivered through the authenticated RoadAssist Vercel API
// while Firebase Support case 10427798 remains open.
const enforceEmailVerification = true;

String normalizeSriLankaPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('07') && digits.length == 10) {
    return '+94${digits.substring(1)}';
  }
  if (digits.startsWith('947') && digits.length == 11) return '+$digits';
  return digits;
}

String? validateSriLankaPhone(String? value) {
  final phone = normalizeSriLankaPhone(value?.trim() ?? '');
  return RegExp(r'^\+947\d{8}$').hasMatch(phone)
      ? null
      : 'Use a valid Sri Lankan mobile number (e.g. 077 123 4567)';
}

String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)
      ? null
      : 'Enter a valid email address';
}

String normalizeVehicleRegistration(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*-\s*'), '-');

String? validateVehicleRegistration(String? value) {
  final registration = normalizeVehicleRegistration(value ?? '');
  return RegExp(r'^(?:[A-Z]{1,3}\s*){1,2}-?\s*\d{4}$').hasMatch(registration)
      ? null
      : 'Use a format such as WP CAB-1234 or CAA-1234';
}

String? validateVehicleModelYear(String? value) {
  final model = value?.trim() ?? '';
  if (model.length < 3 || !RegExp(r'[A-Za-z]').hasMatch(model)) {
    return 'Enter the vehicle model and year';
  }
  final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(model);
  final year = int.tryParse(match?.group(0) ?? '');
  if (year == null || year < 1950 || year > DateTime.now().year + 1) {
    return 'Include a valid year, e.g. Toyota Aqua 2018';
  }
  return null;
}

String? validateCustomVehicleType(String? value) {
  final type = value?.trim() ?? '';
  if (type.isEmpty) return 'Enter your vehicle type';
  if (type.length < 2 || !RegExp(r'[A-Za-z]').hasMatch(type)) {
    return 'Enter a valid vehicle type';
  }
  return null;
}

String? validateBreakdownDescription(String? value) {
  final description = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (description.length < 15) {
    return 'Please describe the problem in at least 15 characters';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(description) ||
      description.split(' ').length < 3) {
    return 'Describe at least three words about the vehicle problem';
  }
  return null;
}

// ============================================================
// SPLASH / ONBOARDING
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    final startedAt = DateTime.now();
    Widget destination = const WelcomeScreen();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await AuthService().getCurrentProfile();
        final profileData = profile.data();
        final role = profileData?['role'] as String?;
        final driverPhoto = profileData?['photoData'] as String?;
        final driverPhotoMissing =
            role == 'driver' && (driverPhoto == null || driverPhoto.isEmpty);
        if (enforceEmailVerification &&
            !user.emailVerified &&
            (role == 'provider' || role == 'driver')) {
          destination = EmailVerificationScreen(role: role!);
        } else if (driverPhotoMissing) {
          await FirebaseAuth.instance.signOut();
          destination = const WelcomeScreen();
        } else if (role == 'provider') {
          destination = const ProviderShell();
        } else if (role == 'driver') {
          destination = const DriverShell();
        } else {
          await FirebaseAuth.instance.signOut();
        }
        if (!driverPhotoMissing &&
            (!enforceEmailVerification || user.emailVerified) &&
            (role == 'provider' || role == 'driver')) {
          unawaited(DeviceService().registerCurrentDevice());
        }
      }
    } catch (_) {
      // A temporary network issue must not trap the user on the splash screen.
      destination = const WelcomeScreen();
    }
    final elapsed = DateTime.now().difference(startedAt);
    const minimumSplash = Duration(milliseconds: 700);
    if (elapsed < minimumSplash)
      await Future<void>.delayed(minimumSplash - elapsed);
    if (mounted) replace(context, destination);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [raNavyDeep, raNavy, raBlueDeep],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const BrandMark(size: 76, elevated: true),
            const SizedBox(height: RaSpace.xl),
            const Text(
              'RoadAssist',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: RaSpace.xs),
            Text(
              'Help when you need it most.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const Spacer(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Dot(active: true, onDark: true),
                Dot(onDark: true),
                Dot(onDark: true),
              ],
            ),
            const SizedBox(height: RaSpace.xxl),
            Text(
              "SRI LANKA'S ROADSIDE NETWORK",
              style: RaText.eyebrowOnDark.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}

class LegacyWelcomeScreen extends StatelessWidget {
  const LegacyWelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const AssetSlot(
            height: 250,
            label: 'WELCOME HERO IMAGE\nSri Lankan coastal road',
            icon: Icons.landscape_outlined,
            assetPath: 'assets/images/welcome_road.jpg',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xl,
                RaSpace.xl,
                RaSpace.xl,
                RaSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: BrandMark(size: 44)),
                  const SizedBox(height: RaSpace.md),
                  const Text(
                    'Reliable Support in\nSri Lanka',
                    textAlign: TextAlign.center,
                    style: RaText.display,
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const Text(
                    'Professional vehicle recovery and repair services at your fingertips, wherever you are on the island.',
                    textAlign: TextAlign.center,
                    style: RaText.bodyMuted,
                  ),
                  const SizedBox(height: RaSpace.xxl),
                  const Text('WHY CHOOSE ROADASSIST', style: RaText.eyebrow),
                  const SizedBox(height: RaSpace.md),
                  const FeatureTile(
                    Icons.flash_on_outlined,
                    'Instant Assistance',
                    'Connect with nearby certified providers',
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const FeatureTile(
                    Icons.location_on_outlined,
                    'Real-time Tracking',
                    'Watch your provider arrive on a live route',
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const FeatureTile(
                    Icons.payments_outlined,
                    'Transparent Pricing',
                    'Review estimated costs before confirming',
                  ),
                  const SizedBox(height: RaSpace.xl),
                  FilledButton(
                    onPressed: () => push(context, const RoleSelectionScreen()),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Started'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: raNavyDeep,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/welcome_assistance.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .3, .62, 1],
              colors: [
                Color(0xB3071A2C),
                Color(0x33071A2C),
                Color(0x12071A2C),
                Color(0xE6071A2C),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Help is closer than you think.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fast, trusted roadside assistance wherever your journey takes you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE5EDF5),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF075866),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => push(context, const RoleSelectionScreen()),
                    child: const Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => push(context, const RoleSelectionScreen()),
                  child: const Text(
                    'Already have an account?  Log in',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose Your Role')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          RaSpace.xl,
          RaSpace.lg,
          RaSpace.xl,
          RaSpace.xl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(RaSpace.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3F9FE), Color(0xFFE5F3FD)],
              ),
              borderRadius: BorderRadius.circular(RaRadius.lg),
              border: Border.all(color: raLine),
            ),
            child: const Row(
              children: [
                IconBadge(
                  Icons.shield_outlined,
                  size: 54,
                  iconSize: 27,
                  color: raBlue,
                  background: Colors.white,
                ),
                SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to RoadAssist', style: RaText.title),
                      SizedBox(height: RaSpace.xs),
                      Text(
                        'Secure roadside support for drivers and service professionals.',
                        style: RaText.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaSpace.xxl),
          const Text('Select your account type', style: RaText.headline),
          const SizedBox(height: RaSpace.xs),
          const Text(
            'Choose how you will use RoadAssist. You can sign in or create an account on the next step.',
            style: RaText.bodyMuted,
          ),
          const SizedBox(height: RaSpace.xl),
          RoleOptionCard(
            icon: Icons.directions_car_filled_outlined,
            title: 'Driver',
            badge: 'GET ASSISTANCE',
            description:
                'Request roadside help, track your provider live and manage vehicle details.',
            buttonLabel: 'Continue as Driver',
            onTap: () => push(context, const LoginScreen(isProvider: false)),
          ),
          const SizedBox(height: RaSpace.md),
          RoleOptionCard(
            icon: Icons.home_repair_service_outlined,
            title: 'Service Provider',
            badge: 'PROFESSIONAL PORTAL',
            description:
                'Receive nearby jobs, navigate to drivers and update service progress.',
            buttonLabel: 'Continue as Provider',
            onTap: () => push(context, const LoginScreen(isProvider: true)),
          ),
          const SizedBox(height: RaSpace.xxl),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RaSpace.md),
                child: Text(
                  'NEED URGENT HELP?',
                  style: RaText.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: RaSpace.sm),
          TextButton.icon(
            onPressed: () => replace(context, const DriverShell()),
            icon: const Icon(Icons.emergency_outlined, size: 18),
            label: const Text('Continue with emergency guest access'),
          ),
          const SizedBox(height: RaSpace.sm),
          const Text(
            'By continuing, you agree to use RoadAssist responsibly.',
            textAlign: TextAlign.center,
            style: RaText.caption,
          ),
        ],
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.isProvider});
  final bool isProvider;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool registerMode = false, obscure = true, loading = false;
  String? registrationPhotoData;
  bool preparingRegistrationPhoto = false;
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final authService = AuthService();

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
    if (!widget.isProvider && registrationPhotoData == null) {
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
      if (registrationPhotoData != null) {
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
      if (enforceEmailVerification && user != null && !user.emailVerified) {
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
                          ? 'Manage roadside requests and active jobs'
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
                    if (registerMode || !widget.isProvider) ...[
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
                                'Required before driver login',
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

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.role});
  final String role;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool checking = false;
  bool sending = false;

  Future<void> checkVerification() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      final verified = await AuthService().refreshEmailVerification();
      if (!mounted) return;
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email is not verified yet. Open the link and try again.',
            ),
          ),
        );
        return;
      }
      await AuthService().restoreSessionServices();
      if (!mounted) return;
      replace(
        context,
        widget.role == 'provider' ? const ProviderShell() : const DriverShell(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to check verification: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> resendVerification() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      await AuthService().sendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'too-many-requests'
                ? 'Please wait before requesting another email.'
                : error.message ?? 'Unable to send verification email.',
          ),
          backgroundColor: raDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconBadge(Icons.mark_email_unread_outlined, size: 72),
              const SizedBox(height: RaSpace.xl),
              const Text(
                'Check your email',
                style: RaText.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RaSpace.sm),
              Text(
                'We sent a verification link to ${FirebaseAuth.instance.currentUser?.email ?? 'your email address'}. Open the link before continuing.',
                style: RaText.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RaSpace.xl),
              FilledButton.icon(
                onPressed: checking ? null : checkVerification,
                icon: checking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('I have verified my email'),
              ),
              const SizedBox(height: RaSpace.sm),
              TextButton(
                onPressed: sending ? null : resendVerification,
                child: Text(sending ? 'Sending…' : 'Resend verification email'),
              ),
              TextButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    replace(context, const WelcomeScreen());
                  }
                },
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool deleting = false;

  Future<void> deleteAccount() async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: raDanger),
        title: const Text('Delete account permanently?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your profile and saved device tokens will be removed. Completed service records may be retained for security and transaction history.',
            ),
            const SizedBox(height: RaSpace.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: RaSpace.md),
            TextField(
              controller: confirmationController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: raDanger),
            onPressed: () {
              final valid =
                  passwordController.text.isNotEmpty &&
                  confirmationController.text.trim() == 'DELETE';
              if (valid) Navigator.pop(dialogContext, true);
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    final password = passwordController.text;
    passwordController.dispose();
    confirmationController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      await AuthService().deleteCurrentAccount(password: password);
      if (!mounted) return;
      replace(context, const WelcomeScreen());
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'wrong-password' || 'invalid-credential' =>
          'The password is incorrect. Account was not deleted.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'requires-recent-login' => 'Please sign out, sign in again and retry.',
        _ => error.message ?? 'Unable to delete the account.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to delete account: $error'),
            backgroundColor: raDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Security')),
      body: ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          InfoStrip(
            icon: Icons.email_outlined,
            title: user?.email ?? 'Email unavailable',
            value: user?.emailVerified == true
                ? 'Email verified'
                : enforceEmailVerification
                ? 'Email verification required'
                : 'Verification temporarily unavailable',
          ),
          const SizedBox(height: RaSpace.md),
          Card(
            child: ListTile(
              leading: const IconBadge(Icons.password_outlined),
              title: const Text('Reset Password', style: RaText.title),
              subtitle: const Text('Receive a secure password-reset email'),
              trailing: const Icon(Icons.chevron_right),
              onTap: user?.email == null
                  ? null
                  : () async {
                      await AuthService().sendPasswordResetEmail(user!.email!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'If this account is available, a password reset link will arrive shortly. Check Spam too.',
                            ),
                          ),
                        );
                      }
                    },
            ),
          ),
          const SizedBox(height: RaSpace.xxl),
          const SectionTitle('Danger Zone'),
          const SizedBox(height: RaSpace.md),
          OutlinedButton.icon(
            onPressed: deleting ? null : deleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: raDanger,
              side: const BorderSide(color: raDanger),
            ),
            icon: deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DRIVER SHELL
// ============================================================

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const DriverHomeScreen(),
      const HistoryScreen(),
      const DriverProfileScreen(),
      const SupportScreen(isProvider: false),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Requests'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String locationLabel = 'Galle Road, Colombo 03, Sri Lanka';
  bool updatingLocation = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  locationProfileSubscription;

  @override
  void initState() {
    super.initState();
    if (signedIn) {
      locationProfileSubscription = AuthService().watchCurrentProfile().listen((
        snapshot,
      ) {
        final saved = snapshot.data()?['currentLocationLabel'] as String?;
        if (mounted && saved != null && saved.trim().isNotEmpty) {
          setState(() => locationLabel = saved);
        }
      });
    }
  }

  @override
  void dispose() {
    locationProfileSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveLocation(
    String label, {
    double? latitude,
    double? longitude,
  }) async {
    setState(() => locationLabel = label);
    if (signedIn) {
      await AuthService().updateCurrentProfile({
        'currentLocationLabel': label,
        'currentLatitude': ?latitude,
        'currentLongitude': ?longitude,
      });
    }
  }

  Future<void> useCurrentHomeLocation() async {
    setState(() => updatingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission is required.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      var label =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          label =
              [
                    place.street,
                    place.locality,
                    place.administrativeArea,
                    place.country,
                  ]
                  .whereType<String>()
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
        }
      } catch (_) {
        // Browser geocoding may be unavailable; coordinates remain accurate.
      }
      await saveLocation(
        label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location updated.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update location: $error')),
        );
    } finally {
      if (mounted) setState(() => updatingLocation = false);
    }
  }

  Future<void> enterLocationManually() async {
    final controller = TextEditingController(text: locationLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Current Location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street, city or landmark',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) await saveLocation(value);
  }

  Future<void> changeHomeLocation() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const IconBadge(Icons.my_location_outlined),
              title: const Text('Use current GPS location'),
              onTap: () => Navigator.pop(context, 'gps'),
            ),
            ListTile(
              leading: const IconBadge(Icons.edit_location_alt_outlined),
              title: const Text('Enter location manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'gps') await useCurrentHomeLocation();
    if (action == 'manual') await enterLocationManually();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DashboardHeader(
          child: Column(
            children: [
              Row(
                children: [
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser == null
                        ? null
                        : AuthService().watchCurrentProfile(),
                    builder: (context, snapshot) {
                      final name =
                          snapshot.data?.data()?['displayName'] as String? ??
                          FirebaseAuth.instance.currentUser?.displayName ??
                          'Driver';
                      final photoData =
                          snapshot.data?.data()?['photoData'] as String?;
                      return Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: photoData == null || photoData.isEmpty
                            ? ProfileInitials(
                                name: name,
                                radius: 24,
                                background: Colors.white,
                              )
                            : ClipOval(
                                child: Image.memory(
                                  base64Decode(photoData),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: RaSpace.md),
                  Expanded(
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseAuth.instance.currentUser == null
                              ? null
                              : AuthService().watchCurrentProfile(),
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.data()?['displayName']
                                    as String? ??
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'Driver';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WELCOME BACK',
                                  style: RaText.eyebrow.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: signedIn
                        ? RequestService().watchDriverRequests()
                        : null,
                    builder: (context, snapshot) {
                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: signedIn
                            ? AuthService().watchCurrentProfile()
                            : null,
                        builder: (context, profileSnapshot) {
                          final seenAt =
                              profileSnapshot.data
                                      ?.data()?['notificationsSeenAt']
                                  as Timestamp?;
                          final count =
                              snapshot.data?.docs.where((doc) {
                                final updatedAt =
                                    doc.data()['updatedAt'] as Timestamp?;
                                return doc.data()['status'] != 'searching' &&
                                    (seenAt == null ||
                                        (updatedAt?.compareTo(seenAt) ?? 1) >
                                            0);
                              }).length ??
                              0;
                          return Badge(
                            isLabelVisible: count > 0,
                            label: Text(count > 9 ? '9+' : '$count'),
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 44),
                              ),
                              tooltip: 'Notifications',
                              onPressed: () {
                                if (signedIn) {
                                  push(
                                    context,
                                    const DriverNotificationsScreen(),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sign in to view request notifications.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.notifications_none),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.md),
              Container(
                padding: const EdgeInsets.all(RaSpace.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: updatingLocation ? null : changeHomeLocation,
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  child: Row(
                    children: [
                      const IconBadge(Icons.location_on_outlined, size: 36),
                      const SizedBox(width: RaSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT LOCATION',
                              style: TextStyle(
                                color: raMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationLabel,
                              style: RaText.title.copyWith(color: raInk),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (updatingLocation)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.edit_location_alt_outlined,
                          color: raBlue,
                          size: 21,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(RaSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(RaSpace.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF182733)
                      : const Color(0xFFF3F9FE),
                  borderRadius: BorderRadius.circular(RaRadius.lg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: raDangerPale,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sos_outlined,
                        color: raDanger,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: RaSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need roadside help?',
                            style: RaText.title.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send your location to nearby providers.',
                            style: RaText.caption.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    FilledButton(
                      onPressed: () =>
                          push(context, const AssistanceTypeScreen()),
                      style: FilledButton.styleFrom(
                        backgroundColor: raDanger,
                        minimumSize: const Size(88, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Get Help'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RaSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.person_search_outlined,
                      label: 'Providers',
                      onTap: () =>
                          push(context, const ProviderDirectoryScreen()),
                    ),
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Requests',
                      onTap: () => push(context, const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: RaSpace.sm),
                  Expanded(
                    child: _DriverQuickAction(
                      icon: Icons.support_agent_outlined,
                      label: 'Support',
                      onTap: () =>
                          push(context, const SupportScreen(isProvider: false)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaSpace.xxl),
              SectionTitle(
                'Nearby Assistance',
                action: 'See All',
                onAction: () => push(context, const ProviderDirectoryScreen()),
              ),
              const SizedBox(height: RaSpace.md),
              const _NearbyProvidersPreview(),
              const SizedBox(height: RaSpace.xxl),
              const SectionTitle('My Requests'),
              const SizedBox(height: RaSpace.md),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: signedIn
                    ? RequestService().watchDriverRequests()
                    : null,
                builder: (context, snapshot) {
                  if (!signedIn) {
                    return const InlineMessage(
                      icon: Icons.login_outlined,
                      text: 'Sign in to view and track your requests.',
                    );
                  }
                  if (snapshot.hasError) {
                    return const InlineMessage(
                      icon: Icons.cloud_off_outlined,
                      text: 'Unable to load your requests.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const InlineMessage(
                      icon: Icons.receipt_long_outlined,
                      text: 'No assistance requests yet.',
                    );
                  }
                  final requests = snapshot.data!.docs;
                  final active = requests.where((request) {
                    return const [
                      'searching',
                      'accepted',
                      'en_route',
                      'arrived',
                    ].contains(request.data()['status']);
                  });
                  return _DriverRequestPreview(
                    request: active.isEmpty ? requests.first : active.first,
                  );
                },
              ),
              const SizedBox(height: RaSpace.xxl),
              const Text('Emergency Contacts', style: RaText.headline),
              const SizedBox(height: RaSpace.md),
              Card(
                child: Column(
                  children: [
                    ContactTile(
                      'Police Emergency',
                      '119',
                      onTap: () => showCallPrompt(
                        context,
                        name: 'Police Emergency',
                        number: '119',
                      ),
                    ),
                    const Divider(height: 1),
                    ContactTile(
                      'Suwa Seriya Ambulance',
                      '1990',
                      onTap: () => showCallPrompt(
                        context,
                        name: 'Suwa Seriya Ambulance',
                        number: '1990',
                      ),
                    ),
                    const Divider(height: 1),
                    const _DriverEmergencyContactTile(),
                  ],
                ),
              ),
              const SizedBox(height: RaSpace.xl),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NearbyProvidersPreview extends StatelessWidget {
  const _NearbyProvidersPreview();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return const InlineMessage(
        icon: Icons.login_outlined,
        text: 'Sign in to see available providers near you.',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AuthService().watchOnlineProviders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Unable to load online providers.',
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final providers = snapshot.data!.docs.take(2).toList();
        if (providers.isEmpty) {
          return const InlineMessage(
            icon: Icons.person_search_outlined,
            text: 'No service providers are online right now.',
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < providers.length; index++) ...[
              if (index > 0) const SizedBox(width: RaSpace.sm),
              Expanded(
                child: _OnlineProviderPreviewCard(
                  data: providers[index].data(),
                ),
              ),
            ],
            if (providers.length == 1) const Spacer(),
          ],
        );
      },
    );
  }
}

class _DriverQuickAction extends StatelessWidget {
  const _DriverQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF182733)
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RaRadius.md),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaSpace.sm,
          vertical: RaSpace.md,
        ),
        child: Column(
          children: [
            IconBadge(icon, size: 38),
            const SizedBox(height: RaSpace.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaText.label.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OnlineProviderPreviewCard extends StatelessWidget {
  const _OnlineProviderPreviewCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] as String? ?? 'Service Provider';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => push(context, const AssistanceTypeScreen()),
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileInitials(name: name, radius: 24),
                  const Spacer(),
                  const StatusPill(label: 'Online', tone: RaTone.success),
                ],
              ),
              const SizedBox(height: RaSpace.md),
              Text(
                name,
                style: RaText.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Available for roadside requests',
                style: RaText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InlineMessage extends StatelessWidget {
  const InlineMessage({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RaSpace.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(RaRadius.md),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Row(
      children: [
        IconBadge(icon, size: 38),
        const SizedBox(width: RaSpace.md),
        Expanded(
          child: Text(
            text,
            style: RaText.bodyMuted.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DriverEmergencyContactTile extends StatelessWidget {
  const _DriverEmergencyContactTile();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return ContactTile(
        'Family Contact',
        'Sign in to configure',
        onTap: () => push(context, const EmergencyScreen()),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AuthService().watchCurrentProfile(),
      builder: (context, snapshot) {
        final contact =
            snapshot.data?.data()?['emergencyContact'] as String? ?? '';
        final configured = contact.trim().isNotEmpty && contact != 'Not added';
        return ContactTile(
          'Family Contact',
          configured ? contact : 'Tap to add contact',
          onTap: () => push(context, const EmergencyScreen()),
        );
      },
    );
  }
}

class _DriverRequestPreview extends StatelessWidget {
  const _DriverRequestPreview({required this.request});
  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final status = data['status'] as String? ?? 'searching';
    final label = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Provider arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
    final tone = status == 'completed'
        ? RaTone.success
        : status == 'cancelled'
        ? RaTone.danger
        : RaTone.info;
    final draft = RequestDraft(
      issue: data['issue'] as String? ?? 'Roadside assistance',
      vehicleType: data['vehicleType'] as String? ?? '',
      modelYear: data['modelYear'] as String? ?? '',
      registration: data['registration'] as String? ?? '',
      description: data['description'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      location: data['locationLabel'] as String? ?? 'Pinned location',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 6.9034,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 79.8525,
      provider:
          data['providerName'] as String? ??
          data['preferredProviderName'] as String? ??
          '',
      preferredProviderId: data['preferredProviderId'] as String? ?? '',
      vehiclePhotoUrls: (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
    void resumeRequest() {
      if (status == 'searching') {
        push(context, SearchingScreen(draft: draft, requestId: request.id));
      } else if (const ['accepted', 'en_route', 'arrived'].contains(status)) {
        push(context, TrackingScreen(draft: draft, requestId: request.id));
      } else {
        push(
          context,
          RealtimeDriverRequestDetailsScreen(requestId: request.id, data: data),
        );
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(RaRadius.lg),
        onTap: resumeRequest,
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.lg),
          child: Row(
            children: [
              const IconBadge(Icons.car_repair_outlined, size: 44),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['issue'] as String? ?? 'Roadside assistance',
                      style: RaText.title,
                    ),
                    const SizedBox(height: 6),
                    StatusPill(label: label, tone: tone),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.chevron_right_rounded, color: raMuted),
                  const SizedBox(height: 4),
                  Text(
                    const [
                          'searching',
                          'accepted',
                          'en_route',
                          'arrived',
                        ].contains(status)
                        ? 'Resume'
                        : 'Details',
                    style: RaText.caption.copyWith(
                      color: raBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (signedIn) AuthService().markNotificationsSeen();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: signedIn ? RequestService().watchDriverRequests() : null,
      builder: (context, snapshot) {
        if (!signedIn)
          return const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to view request notifications.',
          );
        if (snapshot.hasError)
          return const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load updates',
            message: 'Check your connection and try again.',
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!.docs;
        if (requests.isEmpty)
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'No notifications yet',
            message: 'Request status updates will appear here in real time.',
          );
        return ListView.separated(
          padding: const EdgeInsets.all(RaSpace.xl),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: RaSpace.sm),
          itemBuilder: (context, index) {
            final data = requests[index].data();
            final status = data['status'] as String? ?? 'searching';
            final message = switch (status) {
              'searching' => 'Searching for an available provider',
              'accepted' =>
                '${data['providerName'] ?? 'A provider'} accepted your request',
              'en_route' => 'Your provider is on the way',
              'arrived' => 'Your provider has arrived',
              'completed' => 'Your assistance request is complete',
              'cancelled' => 'This request was cancelled',
              _ => 'Request status updated',
            };
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(RaSpace.md),
                leading: IconBadge(
                  status == 'completed'
                      ? Icons.check_circle_outline
                      : Icons.notifications_active_outlined,
                  size: 42,
                ),
                title: Text(message, style: RaText.title),
                subtitle: Text(
                  data['issue'] as String? ?? 'Roadside assistance',
                  style: RaText.bodyMuted,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class ProviderDirectoryScreen extends StatefulWidget {
  const ProviderDirectoryScreen({super.key});
  @override
  State<ProviderDirectoryScreen> createState() =>
      _ProviderDirectoryScreenState();
}

class _ProviderDirectoryScreenState extends State<ProviderDirectoryScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) => !signedIn
      ? Scaffold(
          appBar: AppBar(title: const Text('Nearby Providers')),
          body: const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to search online providers.',
          ),
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Nearby Providers')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(RaSpace.xl),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search provider by name',
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AuthService().watchOnlineProviders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load providers',
                        message: 'Check your connection and try again.',
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final providers = snapshot.data!.docs.where((doc) {
                      final name = (doc.data()['displayName'] as String? ?? '')
                          .toLowerCase();
                      return name.contains(query);
                    }).toList();
                    if (providers.isEmpty)
                      return EmptyState(
                        icon: Icons.person_search_outlined,
                        title: query.isEmpty
                            ? 'No providers online'
                            : 'No matching provider',
                        message: query.isEmpty
                            ? 'Online providers will appear automatically.'
                            : 'Try a different provider name.',
                      );
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        RaSpace.xl,
                        0,
                        RaSpace.xl,
                        RaSpace.xl,
                      ),
                      itemCount: providers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RaSpace.sm),
                      itemBuilder: (context, index) {
                        final provider = providers[index].data();
                        final name =
                            provider['displayName'] as String? ??
                            'Service Provider';
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(RaSpace.md),
                            leading: ProfileInitials(name: name),
                            title: Text(name, style: RaText.title),
                            subtitle: const Text(
                              'Online - accepting requests',
                              style: RaText.bodyMuted,
                            ),
                            trailing: const StatusPill(
                              label: 'Available',
                              tone: RaTone.success,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
}

class BreakdownDetailsScreen extends StatefulWidget {
  const BreakdownDetailsScreen({super.key, required this.issue});
  final String issue;
  @override
  State<BreakdownDetailsScreen> createState() => _BreakdownDetailsScreenState();
}

class _BreakdownDetailsScreenState extends State<BreakdownDetailsScreen> {
  final formKey = GlobalKey<FormState>();
  final modelController = TextEditingController();
  final registrationController = TextEditingController();
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();
  final customVehicleController = TextEditingController();
  String vehicle = 'Sedan / Hatchback';
  final List<String> vehiclePhotoUrls = [];
  bool uploadingVehiclePhoto = false;

  Future<void> addVehiclePhotos() async {
    if (uploadingVehiclePhoto || vehiclePhotoUrls.length >= 3) return;
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
    setState(() => uploadingVehiclePhoto = true);
    try {
      final picker = ImagePicker();
      final photos = source == ImageSource.gallery
          ? await picker.pickMultiImage(
              imageQuality: 75,
              maxWidth: 1600,
              limit: 3 - vehiclePhotoUrls.length,
            )
          : [
              ?await navigator.push<XFile>(
                MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
              ),
            ];
      for (final photo in photos) {
        final photoData = await PhotoUploadService().prepareVehiclePhoto(photo);
        if (vehiclePhotoUrls.length < 3) vehiclePhotoUrls.add(photoData);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
    } finally {
      if (mounted) setState(() => uploadingVehiclePhoto = false);
    }
  }

  @override
  void dispose() {
    modelController.dispose();
    registrationController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    customVehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Breakdown Details')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const AssetSlot(
                  height: 185,
                  label: 'VEHICLE HERO IMAGE\nPremium dark sedan by roadside',
                  icon: Icons.directions_car,
                  assetPath: 'assets/images/vehicle_sedan.jpg',
                ),
                Padding(
                  padding: const EdgeInsets.all(RaSpace.xl),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StepEyebrow(step: 2, of: 4),
                        const SizedBox(height: RaSpace.md),
                        const FormSectionTitle(
                          Icons.directions_car_outlined,
                          'Vehicle Information',
                        ),
                        const SizedBox(height: RaSpace.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: vehicle,
                                isExpanded: true,
                                items:
                                    [
                                          'Sedan / Hatchback',
                                          'SUV',
                                          'Van',
                                          'Motorcycle',
                                          'Other',
                                        ]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(() => vehicle = v!),
                              ),
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              child: TextFormField(
                                controller: modelController,
                                maxLength: 50,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Model / Year',
                                  hintText: 'Toyota Aqua 2018',
                                ),
                                validator: validateVehicleModelYear,
                              ),
                            ),
                          ],
                        ),
                        if (vehicle == 'Other') ...[
                          const SizedBox(height: RaSpace.md),
                          TextFormField(
                            controller: customVehicleController,
                            maxLength: 40,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Other Vehicle Type',
                              hintText: 'e.g. Three Wheeler, Pickup Truck',
                              prefixIcon: Icon(Icons.directions_car_outlined),
                            ),
                            validator: (value) => vehicle == 'Other'
                                ? validateCustomVehicleType(value)
                                : null,
                          ),
                        ],
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          controller: registrationController,
                          maxLength: 16,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Registration Number',
                            hintText: 'WP CAB - 1234',
                          ),
                          validator: validateVehicleRegistration,
                        ),
                        const SizedBox(height: RaSpace.xxl),
                        const FormSectionTitle(
                          Icons.info_outline,
                          'Breakdown Type',
                        ),
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          readOnly: true,
                          initialValue: widget.issue,
                          decoration: const InputDecoration(
                            labelText: 'Primary issue',
                          ),
                        ),
                        const SizedBox(height: RaSpace.md),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 4,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            labelText: 'Detailed description',
                            hintText: 'Describe the symptoms...',
                          ),
                          validator: validateBreakdownDescription,
                        ),
                        const SizedBox(height: RaSpace.xxl),
                        const FormSectionTitle(
                          Icons.add_a_photo_outlined,
                          'Vehicle Photos (Optional)',
                        ),
                        const SizedBox(height: RaSpace.md),
                        OutlinedButton.icon(
                          onPressed:
                              uploadingVehiclePhoto ||
                                  vehiclePhotoUrls.length >= 3
                              ? null
                              : addVehiclePhotos,
                          icon: uploadingVehiclePhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            uploadingVehiclePhoto
                                ? 'Uploading photo...'
                                : 'Add vehicle photos (${vehiclePhotoUrls.length}/3)',
                          ),
                        ),
                        if (vehiclePhotoUrls.isNotEmpty) ...[
                          const SizedBox(height: RaSpace.md),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: vehiclePhotoUrls.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: RaSpace.sm),
                              itemBuilder: (context, index) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      RaRadius.sm,
                                    ),
                                    child: Image.memory(
                                      base64Decode(vehiclePhotoUrls[index]),
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => vehiclePhotoUrls.removeAt(index),
                                      ),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(
                                          Icons.close,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: RaSpace.xxl),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                          ),
                        ),
                        const SizedBox(height: RaSpace.lg),
                        const SafetyBox(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Confirm & Next',
            onTap: () {
              FocusScope.of(context).unfocus();
              if (formKey.currentState?.validate() ?? false) {
                push(
                  context,
                  LocationScreen(
                    draft: RequestDraft(
                      issue: widget.issue,
                      vehicleType: vehicle == 'Other'
                          ? customVehicleController.text.trim()
                          : vehicle,
                      modelYear: modelController.text.trim(),
                      registration: normalizeVehicleRegistration(
                        registrationController.text,
                      ),
                      description: descriptionController.text.trim(),
                      notes: notesController.text.trim(),
                      vehiclePhotoUrls: List.unmodifiable(vehiclePhotoUrls),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? errorMessage;
  bool capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    setState(() => errorMessage = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw CameraException(
          'noCamera',
          'No camera was found on this device.',
        );
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      await controller?.dispose();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => errorMessage =
              error.description ?? 'Camera permission was denied.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => errorMessage = '$error');
    }
  }

  Future<void> capture() async {
    final active = controller;
    if (active == null || !active.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await active.takePicture();
      if (mounted) Navigator.pop(context, photo);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          capturing = false;
          errorMessage = error.description ?? 'Unable to capture the photo.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed && controller == null) {
      initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Take a Photo'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: errorMessage != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: RaSpace.md),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  FilledButton.icon(
                    onPressed: initializeCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          )
        : controller == null || !controller!.value.isInitialized
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller!)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: IconButton.filled(
                    onPressed: capturing ? null : capture,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: raBlue,
                      fixedSize: const Size(68, 68),
                    ),
                    icon: capturing
                        ? const CircularProgressIndicator(strokeWidth: 3)
                        : const Icon(Icons.camera_alt, size: 31),
                  ),
                ),
              ),
            ],
          ),
  );
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.source,
  });
  final IconData icon;
  final String label;
  final ImageSource source;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconBadge(icon),
    title: Text(label, style: RaText.title),
    onTap: () => Navigator.pop(context, source),
  );
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, required this.draft});
  final RequestDraft draft;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late RequestDraft draft;
  late LatLng selectedPoint;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    draft = widget.draft;
    selectedPoint = LatLng(draft.latitude, draft.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) useCurrentLocation();
    });
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      var locationLabel =
          'Current GPS (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          final resolved =
              [
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                    place.country,
                  ]
                  .whereType<String>()
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
          if (resolved.isNotEmpty) locationLabel = resolved;
        }
      } catch (_) {
        // Accurate coordinates remain available when reverse geocoding fails.
      }
      if (!mounted) return;
      setState(() {
        selectedPoint = point;
        draft = draft.copyWith(
          location: locationLabel,
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS updated · accuracy ${position.accuracy.toStringAsFixed(0)} m',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is LocationServiceDisabledException
          ? 'Location services are turned off. Enable GPS or set the pin manually.'
          : error is PermissionDeniedException
          ? 'Location permission was denied. Allow it or set the pin manually.'
          : 'Unable to get GPS location. Please try again or set it manually.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void selectMapPosition(LatLng point) {
    setState(() {
      selectedPoint = point;
      draft = draft.copyWith(
        location:
            'Pinned location (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Breakdown pin moved on the map.')),
    );
  }

  Future<void> editLocation() async {
    var value = draft.location;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit breakdown location'),
        content: TextFormField(
          initialValue: draft.location,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Address or landmark',
            hintText: 'Enter your current location',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final location = value.trim();
              if (location.isNotEmpty) Navigator.pop(dialogContext, location);
            },
            child: const Text('Save Location'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => draft = draft.copyWith(location: result));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Location Confirmation'),
      actions: [
        IconButton(
          onPressed: () => push(context, const GpsIssueScreen()),
          tooltip: 'Test GPS issue state',
          icon: const Icon(Icons.gps_off_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapMock(
                    key: ValueKey(selectedPoint),
                    position: selectedPoint,
                    onPositionSelected: selectMapPosition,
                  ),
                ),
                Positioned(
                  left: RaSpace.lg,
                  right: RaSpace.lg,
                  bottom: RaSpace.lg,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BREAKDOWN POINT', style: RaText.eyebrow),
                          const SizedBox(height: RaSpace.xs),
                          Text(draft.location, style: RaText.headline),
                          const SizedBox(height: RaSpace.xs),
                          StatusPill(
                            label: draft.location.startsWith('Current GPS')
                                ? 'GPS coordinates'
                                : 'Confirmed location',
                            tone: RaTone.warning,
                            dot: false,
                          ),
                          const SizedBox(height: RaSpace.lg),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: locating
                                      ? null
                                      : useCurrentLocation,
                                  icon: locating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(
                                    locating ? 'Locating...' : 'Current GPS',
                                  ),
                                ),
                              ),
                              const SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: editLocation,
                                  icon: const Icon(Icons.edit_location),
                                  label: const Text('Edit Manually'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Confirm Location',
            onTap: () => push(context, ProvidersScreen(draft: draft)),
          ),
        ],
      ),
    ),
  );
}

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key, required this.draft});
  final RequestDraft draft;
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

double? _providerDistanceKm(Map<String, dynamic> data, RequestDraft draft) {
  final latitude = (data['latitude'] as num?)?.toDouble();
  final longitude = (data['longitude'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;
  return Geolocator.distanceBetween(
        draft.latitude,
        draft.longitude,
        latitude,
        longitude,
      ) /
      1000;
}

bool _providerMatchesDraft(Map<String, dynamic> data, RequestDraft draft) {
  final services = (data['services'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList();
  if (services.isNotEmpty && !services.contains(draft.issue)) return false;
  final distanceKm = _providerDistanceKm(data, draft);
  if (distanceKm == null) return true;
  final radiusText = data['serviceRadius'] as String? ?? '15 km';
  final radius =
      double.tryParse(RegExp(r'\d+').firstMatch(radiusText)?.group(0) ?? '') ??
      15;
  return distanceKm <= radius;
}

class _NearbyProvidersMap extends StatelessWidget {
  const _NearbyProvidersMap({required this.draft, required this.selectedId});

  final RequestDraft draft;
  final String? selectedId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService().watchOnlineProviders(),
        builder: (context, snapshot) {
          final providerDocuments = snapshot.data?.docs;
          final providers = providerDocuments == null
              ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : providerDocuments
                    .where(
                      (provider) =>
                          _providerMatchesDraft(provider.data(), draft),
                    )
                    .toList();
          final positions = <LatLng>[];
          LatLng? selectedPosition;
          for (final provider in providers) {
            final data = provider.data();
            final latitude = (data['latitude'] as num?)?.toDouble();
            final longitude = (data['longitude'] as num?)?.toDouble();
            if (latitude == null || longitude == null) continue;
            final point = LatLng(latitude, longitude);
            positions.add(point);
            if (provider.id == selectedId) selectedPosition = point;
          }
          return MapMock(
            position: LatLng(draft.latitude, draft.longitude),
            providerPositions: positions,
            selectedProviderPosition: selectedPosition,
          );
        },
      );
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String? selectedId;
  String? selectedName;

  void scheduleProviderSelection(String? id, String? name) {
    if (selectedId == id && selectedName == name) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedId = id;
        selectedName = name;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nearby Providers')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                const StepEyebrow(step: 3, of: 4),
                const SizedBox(height: RaSpace.md),
                InfoStrip(
                  icon: Icons.location_on,
                  title: 'Your location',
                  value: widget.draft.location,
                ),
                const SizedBox(height: RaSpace.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RaRadius.md),
                  child: SizedBox(
                    height: 185,
                    child: _NearbyProvidersMap(
                      draft: widget.draft,
                      selectedId: selectedId,
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const SectionTitle(
                  'Available Technicians',
                  action: 'List / Map',
                ),
                const SizedBox(height: RaSpace.md),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AuthService().watchOnlineProviders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.cloud_off,
                        title: 'Unable to load providers',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final providers = snapshot.data!.docs
                        .where(
                          (provider) => _providerMatchesDraft(
                            provider.data(),
                            widget.draft,
                          ),
                        )
                        .toList();
                    if (providers.isEmpty) {
                      scheduleProviderSelection(null, null);
                      return const EmptyState(
                        icon: Icons.person_search,
                        title: 'No matching providers nearby',
                        message:
                            'A provider must be online, support this service and be within range.',
                      );
                    }
                    if (!providers.any(
                      (provider) => provider.id == selectedId,
                    )) {
                      scheduleProviderSelection(
                        providers.first.id,
                        providers.first.data()['displayName'] as String? ??
                            'Service Provider',
                      );
                    }
                    return Column(
                      children: providers.map((provider) {
                        final data = provider.data();
                        final name =
                            data['displayName'] as String? ??
                            'Service Provider';
                        final distanceKm = _providerDistanceKm(
                          data,
                          widget.draft,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: RaSpace.sm),
                          child: ProviderTile(
                            name: name,
                            company: 'RoadAssist Service Provider',
                            distance: distanceKm == null
                                ? 'Location pending'
                                : '${distanceKm.toStringAsFixed(1)} km away',
                            eta: 'after acceptance',
                            rating: 'New',
                            selected: selectedId == provider.id,
                            onTap: () => setState(() {
                              selectedId = provider.id;
                              selectedName = name;
                            }),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          BottomAction(
            label: 'Review Request',
            enabled: selectedId != null,
            onTap: () => push(
              context,
              ReviewScreen(
                draft: widget.draft.copyWith(
                  provider: selectedName ?? 'Available Provider',
                  preferredProviderId: selectedId,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.draft});
  final RequestDraft draft;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool submitting = false;

  String formatPrice(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return 'Rs. $digits';
    return 'Rs. ${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}';
  }

  Future<void> submitRequest() async {
    if (submitting) return;
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in as a driver so providers can receive your request.',
          ),
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final requestId = await RequestService().createRequest(widget.draft);
      if (!mounted) return;
      replace(
        context,
        SearchingScreen(draft: widget.draft, requestId: requestId),
      );
    } catch (error) {
      if (!mounted) return;
      final activeRequestExists = error.toString().contains(
        'Complete or cancel your active request',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activeRequestExists
                ? 'Complete or cancel your current request before creating another.'
                : 'Unable to create the request. Please try again.',
          ),
          backgroundColor: raDanger,
        ),
      );
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review Request')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                const StepEyebrow(step: 4, of: 4),
                const SizedBox(height: RaSpace.lg),
                const Text('ASSIGNED PROVIDER', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Row(
                      children: [
                        ProfileInitials(
                          name: widget.draft.provider,
                          radius: 25,
                        ),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.draft.provider, style: RaText.title),
                              const SizedBox(height: 2),
                              const Text(
                                'RoadAssist certified provider',
                                style: RaText.caption,
                              ),
                              const SizedBox(height: RaSpace.xs),
                              const StatusPill(
                                label: 'Available now',
                                tone: RaTone.success,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: raGoldPale,
                            borderRadius: BorderRadius.circular(RaRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: raGold, size: 14),
                              SizedBox(width: 2),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: raGold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const Text('REQUEST DETAILS', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        SummaryRow('Assistance Type', widget.draft.issue),
                        const Divider(),
                        SummaryRow(
                          'Vehicle',
                          '${widget.draft.modelYear} (${widget.draft.vehicleType})',
                        ),
                        const Divider(),
                        SummaryRow(
                          'Registration',
                          widget.draft.registration.toUpperCase(),
                        ),
                        const Divider(),
                        SummaryRow('Pickup Location', widget.draft.location),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const Text('PAYMENT SUMMARY', style: RaText.eyebrow),
                const SizedBox(height: RaSpace.sm),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        SummaryRow(
                          'Initial Service Estimate',
                          formatPrice(widget.draft.serviceFee),
                        ),
                        SummaryRow(
                          'Initial Dispatch Estimate',
                          formatPrice(widget.draft.dispatchFee),
                        ),
                        const Divider(),
                        SummaryRow(
                          'Estimated Total',
                          formatPrice(widget.draft.estimatedCost),
                          strong: true,
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(RaSpace.sm),
                          decoration: BoxDecoration(
                            color: raSuccessPale,
                            borderRadius: BorderRadius.circular(RaRadius.sm),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: raSuccess,
                                size: 17,
                              ),
                              SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: Text(
                                  'This is a system estimate. The provider reviews the issue and distance, then submits an itemised quote before accepting.',
                                  style: TextStyle(
                                    color: raSuccess,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                const InlineMessage(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Secure chat and calling become available after a provider accepts with a quote. Service, travel and extra charges will be shown separately.',
                ),
              ],
            ),
          ),
          BottomAction(
            label: submitting
                ? 'Submitting Request...'
                : 'Confirm Assistance Request',
            enabled: !submitting,
            onTap: submitRequest,
          ),
        ],
      ),
    ),
  );
}

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key, required this.draft, this.requestId});
  final RequestDraft draft;
  final String? requestId;
  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestListener;
  Timer? providerResponseTimer;
  late final AnimationController pulseController;
  String requestStatus = 'searching';
  String? requestError;
  bool searchingAllProviders = false;
  bool navigatingToTracking = false;
  late String currentLocationLabel;

  Future<void> cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: raDanger),
        title: const Text('Cancel assistance request?'),
        content: const Text(
          'The provider search will stop and this request will not be submitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Searching'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: raDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      try {
        if (widget.requestId != null) {
          await RequestService().cancelRequest(widget.requestId!);
        }
        if (!mounted) return;
        replace(context, const DriverShell());
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to cancel the request. Try again.'),
            ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    currentLocationLabel = widget.draft.location;
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    if (widget.requestId == null) {
      requestStatus = 'not_submitted';
      requestError = 'This request was not saved. Sign in and submit again.';
    } else {
      requestListener = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final data = snapshot.data();
              if (!mounted) return;
              if (data == null) {
                setState(() => requestError = 'Request could not be found.');
                return;
              }
              final status = data['status'] as String? ?? 'searching';
              final locationLabel =
                  data['locationLabel'] as String? ?? widget.draft.location;
              final preferredProviderId =
                  data['preferredProviderId'] as String? ?? '';
              if (status == 'searching' && preferredProviderId.isNotEmpty) {
                _scheduleProviderTimeout(data);
              } else {
                providerResponseTimer?.cancel();
                providerResponseTimer = null;
              }
              if (const [
                    'accepted',
                    'en_route',
                    'arrived',
                    'completed',
                  ].contains(status) &&
                  !navigatingToTracking) {
                navigatingToTracking = true;
                final latitude = (data['latitude'] as num?)?.toDouble();
                final longitude = (data['longitude'] as num?)?.toDouble();
                replace(
                  context,
                  TrackingScreen(
                    draft: widget.draft.copyWith(
                      location: locationLabel,
                      latitude: latitude,
                      longitude: longitude,
                    ),
                    requestId: widget.requestId,
                  ),
                );
              } else {
                setState(() {
                  requestStatus = status;
                  currentLocationLabel = locationLabel;
                  requestError = null;
                  searchingAllProviders =
                      widget.draft.preferredProviderId.isNotEmpty &&
                      (data['preferredProviderId'] as String? ?? '').isEmpty;
                });
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  requestError = 'Connection lost. Waiting to reconnect...';
                });
              }
            },
          );
    }
  }

  void _scheduleProviderTimeout(Map<String, dynamic> data) {
    if (providerResponseTimer != null || widget.requestId == null) return;
    const responseWindow = Duration(seconds: 90);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final elapsed = createdAt == null
        ? Duration.zero
        : DateTime.now().difference(createdAt);
    final remaining = elapsed >= responseWindow
        ? Duration.zero
        : responseWindow - elapsed;
    providerResponseTimer = Timer(remaining, () async {
      providerResponseTimer = null;
      try {
        await RequestService().expandProviderSearch(widget.requestId!);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to expand the provider search yet.'),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    requestListener?.cancel();
    providerResponseTimer?.cancel();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                RaSpace.xxl,
                RaSpace.xl,
                RaSpace.xxl,
                RaSpace.lg,
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(
                    label: requestStatus == 'cancelled'
                        ? 'REQUEST CANCELLED'
                        : requestStatus == 'not_submitted'
                        ? 'NOT SUBMITTED'
                        : searchingAllProviders
                        ? 'EXPANDING SEARCH'
                        : 'SEARCHING NEARBY',
                    tone:
                        requestStatus == 'cancelled' ||
                            requestStatus == 'not_submitted'
                        ? RaTone.danger
                        : RaTone.info,
                  ),
                ),
                const SizedBox(height: RaSpace.xxl),
                Center(
                  child: AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) => Transform.scale(
                      scale: 0.88 + (pulseController.value * 0.12),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            raPale,
                            const Color(0xFFAFC3FF),
                            pulseController.value,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: raBlue.withValues(
                                alpha: 0.18 + pulseController.value * 0.18,
                              ),
                              blurRadius: 18 + pulseController.value * 18,
                              spreadRadius: pulseController.value * 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: RotationTransition(
                            turns: pulseController,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: const BoxDecoration(
                                color: raNavy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_searching,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xxl),
                Text(
                  'Finding Your\nRescue Team',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                Text(
                  requestError ??
                      (requestStatus == 'cancelled'
                          ? 'This assistance request has been cancelled.'
                          : searchingAllProviders
                          ? '${widget.draft.provider} was unavailable. Searching other matching providers now.'
                          : widget.draft.provider.isEmpty
                          ? 'Sending your request to an available certified provider.'
                          : 'Sending your request to ${widget.draft.provider}.'),
                  textAlign: TextAlign.center,
                  style: requestError == null
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: raDanger),
                ),
                if (requestStatus == 'searching' &&
                    widget.draft.preferredProviderId.isNotEmpty &&
                    !searchingAllProviders) ...[
                  const SizedBox(height: RaSpace.lg),
                  const InlineMessage(
                    icon: Icons.schedule_outlined,
                    text:
                        'If this provider does not respond within 90 seconds, we will automatically search other matching providers.',
                  ),
                ],
                const SizedBox(height: RaSpace.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: StatusPill(
                            label: requestStatus == 'cancelled'
                                ? 'Cancelled'
                                : requestStatus == 'not_submitted'
                                ? 'Not submitted'
                                : 'Searching',
                            tone:
                                requestStatus == 'cancelled' ||
                                    requestStatus == 'not_submitted'
                                ? RaTone.danger
                                : RaTone.info,
                          ),
                        ),
                        SummaryRow(
                          'Request ID',
                          widget.requestId ?? 'Not submitted',
                        ),
                        SummaryRow('Assistance Type', widget.draft.issue),
                        SummaryRow('Current Location', currentLocationLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.xxl,
              RaSpace.sm,
              RaSpace.xxl,
              RaSpace.lg,
            ),
            child: requestStatus == 'searching'
                ? SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: cancelRequest,
                      style: TextButton.styleFrom(foregroundColor: raDanger),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel Request'),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: () => replace(context, const DriverShell()),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to Home'),
                  ),
          ),
        ],
      ),
    ),
  );
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request History')),
    body: !signedIn
        ? const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to view request history.',
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.xl,
                  RaSpace.xl,
                  RaSpace.xl,
                  RaSpace.md,
                ),
                child: FilterRow(
                  selected: filter,
                  onSelected: (value) => setState(() => filter = value),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: RequestService().watchDriverRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load history',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final requests = snapshot.data!.docs.where((request) {
                      final status = request.data()['status'] as String? ?? '';
                      if (filter == 1) return status == 'completed';
                      if (filter == 2) return status == 'cancelled';
                      return true;
                    }).toList();
                    if (requests.isEmpty) {
                      return EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: filter == 0
                            ? 'No requests yet'
                            : 'No matching requests',
                        message: filter == 0
                            ? 'Your assistance requests will appear here.'
                            : 'There are no requests in this category.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        RaSpace.xl,
                        0,
                        RaSpace.xl,
                        RaSpace.xl,
                      ),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RaSpace.md),
                      itemBuilder: (context, index) => _DriverHistoryCard(
                        requestId: requests[index].id,
                        data: requests[index].data(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

class _DriverHistoryCard extends StatelessWidget {
  const _DriverHistoryCard({required this.requestId, required this.data});
  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'searching';
    final statusLabel = switch (status) {
      'searching' => 'Searching',
      'accepted' => 'Accepted',
      'en_route' => 'En route',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
    final tone = status == 'completed'
        ? RaTone.success
        : status == 'cancelled'
        ? RaTone.danger
        : RaTone.info;
    final provider =
        data['providerName'] as String? ??
        (status == 'searching' ? 'Finding a provider' : 'Not assigned');
    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateLabel = createdAt == null
        ? 'Date unavailable'
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}  ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel.toUpperCase(), style: RaText.eyebrow),
            const SizedBox(height: RaSpace.sm),
            Row(
              children: [
                const IconBadge(Icons.car_repair_outlined, size: 38),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Text(
                    data['issue'] as String? ?? 'Roadside assistance',
                    style: RaText.title,
                  ),
                ),
                StatusPill(label: statusLabel, tone: tone),
              ],
            ),
            const Divider(height: RaSpace.xxl),
            SummaryRow('Provider', provider),
            SummaryRow('Vehicle', vehicle.isEmpty ? 'Not provided' : vehicle),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Pinned location',
            ),
            SummaryRow(
              status == 'completed' ? 'Total Cost' : 'Estimated Cost',
              'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
              strong: true,
            ),
            if (data['driverRating'] != null)
              SummaryRow('Your Rating', '${data['driverRating']} / 5 stars'),
            const SizedBox(height: RaSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => push(
                  context,
                  RealtimeDriverRequestDetailsScreen(
                    requestId: requestId,
                    data: data,
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RealtimeDriverRequestDetailsScreen extends StatelessWidget {
  const RealtimeDriverRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });
  final String requestId;
  final Map<String, dynamic> data;

  void showReceipt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.receipt_long_outlined, color: raBlue),
        title: Text('Receipt $requestId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SummaryRow(
              'Service',
              data['issue'] as String? ?? 'Roadside assistance',
            ),
            SummaryRow(
              'Provider',
              data['providerName'] as String? ?? 'Service Provider',
            ),
            SummaryRow(
              'Vehicle',
              data['registration'] as String? ?? 'Not provided',
            ),
            const Divider(),
            SummaryRow('Service charge', 'Rs. ${data['serviceFee'] ?? 0}'),
            SummaryRow(
              'Travel / distance charge',
              'Rs. ${data['dispatchFee'] ?? 0}',
            ),
            SummaryRow('Extra charge', 'Rs. ${data['extraFee'] ?? 0}'),
            if ((data['providerDistanceKm'] as num?) != null)
              SummaryRow(
                'Provider distance',
                '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
              ),
            if ((data['quoteNotes'] as String? ?? '').isNotEmpty)
              SummaryRow('Quote notes', data['quoteNotes'] as String),
            const Divider(),
            SummaryRow(
              'Total',
              'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
              strong: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> rateService(BuildContext context) async {
    var selectedRating = (data['driverRating'] as num?)?.toInt() ?? 0;
    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rate Your Service', style: RaText.headline),
                const SizedBox(height: RaSpace.xs),
                const Text(
                  'How was your roadside assistance experience?',
                  style: RaText.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RaSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () =>
                          setSheetState(() => selectedRating = index + 1),
                      icon: Icon(
                        index < selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: raGold,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedRating == 0
                        ? null
                        : () => Navigator.pop(sheetContext, selectedRating),
                    child: const Text('Submit Rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (rating == null || !context.mounted) return;
    try {
      await RequestService().submitDriverRating(requestId, rating);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your $rating-star rating.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save rating. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final provider = data['providerName'] as String? ?? 'Not assigned';
    final providerPhone = data['providerPhone'] as String? ?? '';
    final status = (data['status'] as String? ?? 'searching').replaceAll(
      '_',
      ' ',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          SizedBox(
            height: 210,
            child: MapMock(position: LatLng(latitude, longitude)),
          ),
          const SizedBox(height: RaSpace.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  SummaryRow('Request ID', requestId),
                  SummaryRow('Status', status),
                  SummaryRow(
                    'Assistance Type',
                    data['issue'] as String? ?? 'Roadside assistance',
                  ),
                  SummaryRow('Provider', provider),
                  SummaryRow(
                    'Vehicle',
                    data['modelYear'] as String? ??
                        data['vehicleType'] as String? ??
                        'Not provided',
                  ),
                  SummaryRow(
                    'Registration',
                    data['registration'] as String? ?? 'Not provided',
                  ),
                  SummaryRow(
                    'Location',
                    data['locationLabel'] as String? ?? 'Pinned location',
                  ),
                  SummaryRow(
                    'Description',
                    data['description'] as String? ?? 'No description',
                  ),
                  const Divider(),
                  SummaryRow(
                    'Service Charge',
                    'Rs. ${data['serviceFee'] ?? 0}',
                  ),
                  SummaryRow(
                    'Travel / Distance Charge',
                    'Rs. ${data['dispatchFee'] ?? 0}',
                  ),
                  SummaryRow('Extra Charge', 'Rs. ${data['extraFee'] ?? 0}'),
                  if ((data['providerDistanceKm'] as num?) != null)
                    SummaryRow(
                      'Provider Distance',
                      '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
                    ),
                  if ((data['quoteNotes'] as String? ?? '').isNotEmpty)
                    SummaryRow('Quote Notes', data['quoteNotes'] as String),
                  const Divider(),
                  SummaryRow(
                    data['finalCost'] == null ? 'Quoted Total' : 'Final Total',
                    'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: providerPhone.isEmpty
                      ? null
                      : () => showCallPrompt(
                          context,
                          name: provider,
                          number: providerPhone,
                        ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call Provider'),
                ),
              ),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: data['providerId'] == null
                      ? null
                      : () => push(
                          context,
                          ChatScreen(
                            requestId: requestId,
                            peerName: provider,
                            peerPhone: providerPhone,
                          ),
                        ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Chat'),
                ),
              ),
            ],
          ),
          if (data['status'] == 'completed') ...[
            const SizedBox(height: RaSpace.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showReceipt(context),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Receipt'),
                  ),
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => rateService(context),
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(
                      data['driverRating'] == null
                          ? 'Rate Service'
                          : 'Update Rating',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Icon(icon, color: raMuted, size: 17),
        const SizedBox(width: RaSpace.sm),
        Expanded(child: Text(label, style: RaText.caption)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RaText.label,
          ),
        ),
      ],
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.isProvider});

  final bool isProvider;

  Future<void> showAppSupport(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            0,
            RaSpace.xl,
            RaSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('RoadAssist App Support', style: RaText.headline),
              const SizedBox(height: RaSpace.xs),
              Text(
                'Run quick checks or manage your account securely.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: RaSpace.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(Icons.wifi_outlined),
                title: const Text('Connection checklist'),
                subtitle: const Text(
                  'Internet, location and notification permissions',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showInformation(
                    context,
                    'Connection Checklist',
                    '1. Confirm mobile data or Wi-Fi is connected.\n\n2. Allow precise location permission.\n\n3. Allow notification permission.\n\n4. Restart RoadAssist and try again.',
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(Icons.copy_all_outlined),
                title: const Text('Copy account diagnostics'),
                subtitle: Text(user?.email ?? 'Guest session'),
                onTap: () async {
                  final details =
                      'RoadAssist support details\nAccount: ${user?.email ?? 'Guest'}\nRole: ${isProvider ? 'Provider' : 'Driver'}\nPlatform: ${Theme.of(context).platform.name}';
                  await Clipboard.setData(ClipboardData(text: details));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support details copied.')),
                    );
                  }
                },
              ),
              if (user != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconBadge(Icons.manage_accounts_outlined),
                  title: const Text('Account & Security'),
                  subtitle: const Text(
                    'Password, verification and account deletion',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    push(context, const AccountSecurityScreen());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showLocationSupport(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            0,
            RaSpace.xl,
            RaSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Location & Live Tracking', style: RaText.headline),
              const SizedBox(height: RaSpace.sm),
              const Text(
                'Precise location must be enabled while an assistance request is active.',
              ),
              const SizedBox(height: RaSpace.lg),
              FilledButton.icon(
                onPressed: () => Geolocator.openLocationSettings(),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Open Location Settings'),
              ),
              const SizedBox(height: RaSpace.sm),
              OutlinedButton.icon(
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open App Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showInformation(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [Color(0xFF182733), Color(0xFF203746)]
                  : const [Color(0xFFEAF5FE), Color(0xFFF7FBFF)],
            ),
            borderRadius: BorderRadius.circular(RaRadius.lg),
            border: Border.all(color: raLine),
          ),
          child: Column(
            children: [
              const IconBadge(
                Icons.support_agent_outlined,
                size: 58,
                iconSize: 29,
              ),
              const SizedBox(height: RaSpace.md),
              Text(
                'How can we help?',
                style: RaText.headline.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: RaSpace.xs),
              Text(
                'RoadAssist support and safety information is available here.',
                textAlign: TextAlign.center,
                style: RaText.bodyMuted.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Quick Support'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconBadge(Icons.support_agent_outlined),
                title: const Text(
                  'RoadAssist App Support',
                  style: RaText.title,
                ),
                subtitle: const Text(
                  'Account and app troubleshooting',
                  style: RaText.caption,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppSupport(context),
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: const IconBadge(
                  Icons.emergency_outlined,
                  color: raDanger,
                  background: raDangerPale,
                ),
                title: const Text('Emergency Services', style: RaText.title),
                subtitle: const Text(
                  'Police emergency hotline 119',
                  style: RaText.caption,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showCallPrompt(
                  context,
                  name: 'Emergency Services',
                  number: '119',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Frequently Asked Questions'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: raBlue),
                title: Text(
                  isProvider
                      ? 'How do I receive requests?'
                      : 'How do I request assistance?',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showInformation(
                  context,
                  isProvider ? 'Receiving Requests' : 'Requesting Assistance',
                  isProvider
                      ? 'Keep your provider status Active, allow location access and configure the services you offer. Matching nearby requests appear in real time.'
                      : 'Open Home, choose an assistance type, enter vehicle details, confirm your location and select an available provider.',
                ),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: raBlue),
                title: const Text(
                  'Location and live tracking',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLocationSupport(context),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: raBlue),
                title: const Text(
                  'Privacy and account safety',
                  style: RaText.title,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    push(context, PrivacySafetyScreen(isProvider: isProvider)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PrivacySafetyScreen extends StatelessWidget {
  const PrivacySafetyScreen({super.key, required this.isProvider});

  final bool isProvider;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Account Safety')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        const InfoStrip(
          icon: Icons.verified_user_outlined,
          title: 'Your information is protected',
          value: 'RoadAssist only shares details needed for active assistance.',
        ),
        const SizedBox(height: RaSpace.xl),
        const SectionTitle('Privacy controls'),
        const SizedBox(height: RaSpace.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const IconBadge(Icons.location_on_outlined),
                title: const Text('Location access', style: RaText.title),
                subtitle: const Text(
                  'Used for nearby matching and live assistance',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Geolocator.openAppSettings(),
              ),
              const Divider(height: 1, indent: 62),
              ListTile(
                leading: const IconBadge(Icons.lock_outline),
                title: const Text('Account & Security', style: RaText.title),
                subtitle: const Text(
                  'Password, verification and account deletion',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const AccountSecurityScreen()),
              ),
              const Divider(height: 1, indent: 62),
              ListTile(
                leading: const IconBadge(Icons.visibility_outlined),
                title: const Text(
                  'Who can see my details?',
                  style: RaText.title,
                ),
                subtitle: Text(
                  isProvider
                      ? 'Only drivers assigned to your active jobs can view service contact details.'
                      : 'Only the provider assigned to your active request can view the required contact and vehicle details.',
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Information visibility'),
                    content: Text(
                      isProvider
                          ? 'Drivers can access the provider information required for an accepted job. Other users cannot access your private account data.'
                          : 'Your assigned provider receives only the information required to complete the active roadside request. Never share your password or verification codes.',
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
        const SizedBox(height: RaSpace.xl),
        const SafetyBox(),
      ],
    ),
  );
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> editContact(BuildContext context, String currentContact) async {
    final formKey = GlobalKey<FormState>();
    var updatedContact = currentContact == 'Not added' ? '' : currentContact;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Form(
        key: formKey,
        child: AlertDialog(
          title: const Text('Emergency Contact'),
          content: TextFormField(
            initialValue: updatedContact,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+94 77 123 4567',
              prefixIcon: Icon(Icons.contact_emergency_outlined),
            ),
            validator: validateSriLankaPhone,
            onChanged: (value) => updatedContact = value,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  dialogContext,
                  normalizeSriLankaPhone(updatedContact),
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  dialogContext,
                  normalizeSriLankaPhone(updatedContact),
                );
              },
              child: const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    try {
      await AuthService().updateCurrentProfile({'emergencyContact': value});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contact saved.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save emergency contact: $error'),
            backgroundColor: raDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Emergency Contact')),
    body: !signedIn
        ? const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to manage an emergency contact.',
          )
        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService().watchCurrentProfile(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load contact',
                  message: 'Check your connection and try again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!.data() ?? {};
              final contact = data['emergencyContact'] as String? ?? '';
              final configured =
                  contact.trim().isNotEmpty && contact != 'Not added';
              final location =
                  data['currentLocationLabel'] as String? ??
                  'Current location not available';
              return ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  InfoStrip(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Family Contact',
                    value: configured ? contact : 'No contact added',
                  ),
                  const SizedBox(height: RaSpace.md),
                  OutlinedButton.icon(
                    onPressed: () => editContact(context, contact),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(configured ? 'Change Contact' : 'Add Contact'),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RaRadius.md),
                    child: const SizedBox(height: 250, child: MapMock()),
                  ),
                  const SizedBox(height: RaSpace.md),
                  FilledButton.icon(
                    onPressed: configured
                        ? () => showCallPrompt(
                            context,
                            name: 'Family Contact',
                            number: contact,
                          )
                        : null,
                    icon: const Icon(Icons.call),
                    label: const Text('Call Emergency Contact'),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: location == 'Current location not available'
                        ? null
                        : () => copyLocation(context, location),
                    icon: const Icon(Icons.share_location),
                    label: const Text('Share Current Location'),
                  ),
                ],
              );
            },
          ),
  );
}

// ============================================================
// PROVIDER SHELL
// ============================================================

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && index != 0) setState(() => index = 0);
    },
    child: Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ProviderHomeScreen(),
          ProviderNotificationsScreen(),
          ProviderHistoryScreen(),
          ProviderProfileScreen(),
          SupportScreen(isProvider: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Help',
          ),
        ],
      ),
    ),
  );
}

bool _requestMatchesProvider(
  Map<String, dynamic> data,
  String userId, {
  List<String>? services,
}) {
  final rejected = data['rejectedBy'] as List<dynamic>? ?? const [];
  final preferredProviderId = data['preferredProviderId'] as String? ?? '';
  final isPreferred =
      preferredProviderId.isEmpty || preferredProviderId == userId;
  final supportsService =
      services == null || services.contains(data['issue'] as String? ?? '');
  return isPreferred && !rejected.contains(userId) && supportsService;
}

class _ProviderRealtimeStats extends StatelessWidget {
  const _ProviderRealtimeStats({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: RequestService().watchOpenRequests(),
        builder: (context, openSnapshot) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService().watchProviderRequests(),
              builder: (context, assignedSnapshot) {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                final newCount =
                    openSnapshot.data?.docs.where((request) {
                      return userId != null &&
                          _requestMatchesProvider(
                            request.data(),
                            userId,
                            services: services,
                          );
                    }).length ??
                    0;
                final assigned = assignedSnapshot.data?.docs ?? const [];
                final activeCount = assigned.where((request) {
                  return const [
                    'accepted',
                    'en_route',
                    'arrived',
                  ].contains(request.data()['status']);
                }).length;
                final completedCount = assigned
                    .where((request) => request.data()['status'] == 'completed')
                    .length;
                return Row(
                  children: [
                    Expanded(
                      child: ProviderStat(
                        value: newCount.toString().padLeft(2, '0'),
                        label: 'New requests',
                        icon: Icons.mark_email_unread_outlined,
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: ProviderStat(
                        value: activeCount.toString().padLeft(2, '0'),
                        label: 'Active jobs',
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: ProviderStat(
                        value: completedCount.toString().padLeft(2, '0'),
                        label: 'Completed',
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
      );
}

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});
  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderPresenceAvatar extends StatelessWidget {
  const _ProviderPresenceAvatar({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      ProfileInitials(
        name: name,
        foregroundColor: Colors.white,
        background: Colors.white24,
      ),
      Positioned(
        right: -2,
        bottom: -2,
        child: Tooltip(
          message: online ? 'Active now' : 'Offline',
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: online ? raSuccess : raMuted,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ProviderRequestBadge extends StatelessWidget {
  const _ProviderRequestBadge({required this.services});
  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: signedIn ? RequestService().watchOpenRequests() : null,
        builder: (context, snapshot) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final count =
              snapshot.data?.docs.where((request) {
                final data = request.data();
                return userId != null &&
                    _requestMatchesProvider(data, userId, services: services);
              }).length ??
              0;
          return Badge(
            isLabelVisible: count > 0,
            backgroundColor: raDanger,
            label: Text(count > 9 ? '9+' : '$count'),
            child: IconButton(
              tooltip: 'New requests',
              onPressed: () =>
                  push(context, const ProviderNotificationsScreen()),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          );
        },
      );
}

class ProviderNotificationsScreen extends StatelessWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Assistance Requests')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: signedIn ? AuthService().watchCurrentProfile() : null,
      builder: (context, profileSnapshot) {
        final savedServices =
            profileSnapshot.data?.data()?['services'] as List<dynamic>?;
        final services = savedServices == null || savedServices.isEmpty
            ? const [
                'Vehicle Towing',
                'Battery Jumpstart',
                'Flat Tyre',
                'General Mechanic',
              ]
            : savedServices.whereType<String>().toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: signedIn ? RequestService().watchOpenRequests() : null,
          builder: (context, snapshot) {
            if (!signedIn) {
              return const EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message: 'Sign in as a provider to view new requests.',
              );
            }
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load requests',
                message: 'Check your connection and try again.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final userId = FirebaseAuth.instance.currentUser!.uid;
            final requests = snapshot.data!.docs.where((request) {
              return _requestMatchesProvider(
                request.data(),
                userId,
                services: services,
              );
            }).toList();
            if (requests.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No new requests',
                message:
                    'Matching driver requests will appear here in real time.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(RaSpace.xl),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: RaSpace.md),
              itemBuilder: (context, index) {
                final request = requests[index];
                final data = request.data();
                final driver = data['driverName'] as String? ?? 'Driver';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ProfileInitials(name: driver, radius: 21),
                            const SizedBox(width: RaSpace.md),
                            Expanded(child: Text(driver, style: RaText.title)),
                            const StatusPill(
                              label: 'New',
                              tone: RaTone.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.md),
                        SummaryRow(
                          'Service',
                          data['issue'] as String? ?? 'Roadside assistance',
                        ),
                        SummaryRow(
                          'Location',
                          data['locationLabel'] as String? ?? 'Pinned location',
                        ),
                        SummaryRow(
                          'Initial System Estimate',
                          'Rs. ${data['estimatedCost'] ?? 0}',
                          strong: true,
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await RequestService().rejectRequest(
                                    request.id,
                                  );
                                },
                                child: const Text('Dismiss'),
                              ),
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  try {
                                    final quote = await requestProviderQuote(
                                      context,
                                      data,
                                    );
                                    if (quote == null || !context.mounted) {
                                      return;
                                    }
                                    await RequestService().acceptRequest(
                                      request.id,
                                      serviceFee: quote['serviceFee'] as int,
                                      travelFee: quote['travelFee'] as int,
                                      extraFee: quote['extraFee'] as int,
                                      providerDistanceKm:
                                          quote['providerDistanceKm'] as double,
                                      quoteNotes: quote['quoteNotes'] as String,
                                    );
                                    if (!context.mounted) return;
                                    final acceptedData =
                                        Map<String, dynamic>.from(data)
                                          ..addAll(quote)
                                          ..['dispatchFee'] = quote['travelFee']
                                          ..['estimatedCost'] =
                                              (quote['serviceFee'] as int) +
                                              (quote['travelFee'] as int) +
                                              (quote['extraFee'] as int)
                                          ..['status'] = 'accepted';
                                    replace(
                                      context,
                                      ProviderActiveJobScreen(
                                        requestId: request.id,
                                        requestData: acceptedData,
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    final activeJob = error.toString().contains(
                                      'Complete your active job',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          activeJob
                                              ? 'Complete your active job before accepting another request.'
                                              : 'This request is no longer available.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Review & Quote'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ),
  );
}

class _ProviderActiveJobsSection extends StatelessWidget {
  const _ProviderActiveJobsSection();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchProviderRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final activeJobs = snapshot.data!.docs.where((request) {
          return const [
            'accepted',
            'en_route',
            'arrived',
          ].contains(request.data()['status']);
        }).toList();
        if (activeJobs.isEmpty) return const SizedBox.shrink();
        final job = activeJobs.first;
        final data = job.data();
        final driver = data['driverName'] as String? ?? 'Driver';
        final status = (data['status'] as String? ?? 'accepted').replaceAll(
          '_',
          ' ',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Active Job'),
            const SizedBox(height: RaSpace.md),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(RaRadius.lg),
                onTap: () => push(
                  context,
                  ProviderActiveJobScreen(requestId: job.id, requestData: data),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(RaSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfileInitials(name: driver, radius: 22),
                          const SizedBox(width: RaSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver, style: RaText.title),
                                Text(
                                  data['issue'] as String? ??
                                      'Roadside assistance',
                                  style: RaText.caption,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(label: status, tone: RaTone.info),
                        ],
                      ),
                      const SizedBox(height: RaSpace.md),
                      Text(
                        data['locationLabel'] as String? ?? 'Pinned location',
                        style: RaText.bodyMuted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RaSpace.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => push(
                            context,
                            ProviderActiveJobScreen(
                              requestId: job.id,
                              requestData: data,
                            ),
                          ),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Resume Active Job'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: RaSpace.xxl),
          ],
        );
      },
    );
  }
}

class _ProviderServicesOverview extends StatelessWidget {
  const _ProviderServicesOverview({
    required this.services,
    required this.serviceRadius,
    required this.onManage,
  });

  final List<String> services;
  final String serviceRadius;
  final VoidCallback onManage;

  IconData iconFor(String service) => switch (service) {
    'Vehicle Towing' => Icons.fire_truck_outlined,
    'Battery Jumpstart' => Icons.battery_charging_full,
    'Flat Tyre' => Icons.tire_repair_outlined,
    'General Mechanic' => Icons.car_repair_outlined,
    _ => Icons.home_repair_service_outlined,
  };

  String detailFor(String service) => switch (service) {
    'Vehicle Towing' => 'Recovery and transport',
    'Battery Jumpstart' => 'Battery and power recovery',
    'Flat Tyre' => 'Tyre repair and replacement',
    'General Mechanic' => 'Diagnostics and roadside repair',
    _ => 'Roadside assistance service',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle('Registered Services', action: 'Manage', onAction: onManage),
      const SizedBox(height: RaSpace.xs),
      Text('Coverage: $serviceRadius', style: RaText.caption),
      const SizedBox(height: RaSpace.md),
      if (services.isEmpty)
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const IconBadge(Icons.add_business_outlined),
            title: const Text('Add your services', style: RaText.title),
            subtitle: const Text(
              'Choose services to receive matching requests.',
              style: RaText.caption,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onManage,
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: RaSpace.sm,
            mainAxisSpacing: RaSpace.sm,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(RaRadius.lg),
                onTap: onManage,
                child: Padding(
                  padding: const EdgeInsets.all(RaSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(iconFor(service), size: 34, iconSize: 18),
                      const Spacer(),
                      Text(
                        service,
                        style: RaText.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detailFor(service),
                        style: RaText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _ProviderNewRequestsBanner extends StatelessWidget {
  const _ProviderNewRequestsBanner({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: signedIn ? RequestService().watchOpenRequests() : null,
        builder: (context, snapshot) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final count =
              snapshot.data?.docs.where((request) {
                return userId != null &&
                    _requestMatchesProvider(
                      request.data(),
                      userId,
                      services: services,
                    );
              }).length ??
              0;
          return FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: count > 0 ? const Color(0xFFF09500) : raBlue,
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: () => push(context, const ProviderNotificationsScreen()),
            icon: Icon(
              count > 0
                  ? Icons.notifications_active_outlined
                  : Icons.inbox_outlined,
            ),
            label: Text(
              count > 0
                  ? 'View $count New ${count == 1 ? 'Request' : 'Requests'}'
                  : 'View Assistance Requests',
            ),
          );
        },
      );
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with WidgetsBindingObserver {
  bool online = true;
  bool wantsToBeOnline = true;
  String serviceRadius = '15 km from current location';
  List<String> providerServices = const [
    'Vehicle Towing',
    'Battery Jumpstart',
    'Flat Tyre',
    'General Mechanic',
  ];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  openRequestsSubscription;
  Set<String> knownOpenRequestIds = <String>{};
  bool openRequestsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AuthService().setProviderOnline(true));
    unawaited(_publishProviderLocation());
    profileSubscription = AuthService().watchCurrentProfile().listen((
      snapshot,
    ) {
      final savedServices = snapshot.data()?['services'] as List<dynamic>?;
      final savedRadius = snapshot.data()?['serviceRadius'] as String?;
      if (mounted) {
        setState(() {
          if (savedServices != null && savedServices.isNotEmpty) {
            providerServices = savedServices.whereType<String>().toList();
          }
          if (savedRadius != null && savedRadius.trim().isNotEmpty) {
            serviceRadius = savedRadius;
          }
        });
      }
    });
    openRequestsSubscription = RequestService().watchOpenRequests().listen(
      _handleOpenRequestUpdates,
    );
  }

  String get dashboardTitle {
    final towing = providerServices.contains('Vehicle Towing');
    final mechanic =
        providerServices.contains('General Mechanic') ||
        providerServices.contains('Flat Tyre') ||
        providerServices.contains('Battery Jumpstart');
    if (towing && !mechanic) return 'Tow Operator Dashboard';
    if (mechanic && !towing) return 'Mechanic Dashboard';
    return 'Provider Dashboard';
  }

  String get providerSpecialty {
    if (providerServices.isEmpty) return 'Roadside assistance professional';
    if (providerServices.length == 1) return providerServices.first;
    return '${providerServices.first} + ${providerServices.length - 1} more';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!signedIn) return;
    if (state == AppLifecycleState.resumed) {
      if (wantsToBeOnline) {
        setState(() => online = true);
        unawaited(AuthService().setProviderOnline(true));
        unawaited(_publishProviderLocation());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (online) {
        setState(() => online = false);
        unawaited(AuthService().setProviderOnline(false));
      }
    }
  }

  Future<void> _publishProviderLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await AuthService().updateProviderDirectoryLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Nearby matching remains available for providers with older profiles.
    }
  }

  void _handleOpenRequestUpdates(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final matchingRequests = snapshot.docs.where((request) {
      return _requestMatchesProvider(
        request.data(),
        userId,
        services: providerServices,
      );
    }).toList();
    final currentIds = matchingRequests.map((request) => request.id).toSet();
    if (!openRequestsInitialized) {
      knownOpenRequestIds = currentIds;
      openRequestsInitialized = true;
      return;
    }
    final newRequests = matchingRequests
        .where((request) => !knownOpenRequestIds.contains(request.id))
        .toList();
    knownOpenRequestIds = currentIds;
    if (!mounted || !online || newRequests.isEmpty) return;

    final latest = newRequests.first.data();
    final driverName = latest['driverName'] as String? ?? 'A driver';
    final issue = latest['issue'] as String? ?? 'roadside assistance';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('$driverName needs $issue'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => push(context, const ProviderNotificationsScreen()),
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (signedIn && online) {
      unawaited(AuthService().setProviderOnline(false));
    }
    profileSubscription?.cancel();
    openRequestsSubscription?.cancel();
    super.dispose();
  }

  Widget requestCard({required Map<String, dynamic> data, String? requestId}) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RaRadius.sm),
              child: SizedBox(
                height: 150,
                child: MapMock(position: LatLng(latitude, longitude)),
              ),
            ),
            const SizedBox(height: RaSpace.md),
            SummaryRow(
              'Driver',
              data['driverName'] as String? ?? 'Nearby Driver',
            ),
            SummaryRow(
              'Vehicle',
              data['modelYear'] as String? ?? 'Vehicle details unavailable',
            ),
            SummaryRow('Issue', data['issue'] as String? ?? 'Roadside help'),
            SummaryRow(
              'Location',
              data['locationLabel'] as String? ?? 'Pinned location',
            ),
            SummaryRow(
              'Initial System Estimate',
              'Rs. ${data['estimatedCost'] ?? 2850}',
              strong: true,
            ),
            const SizedBox(height: RaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: raDanger,
                      side: const BorderSide(color: raLine),
                    ),
                    onPressed: () async {
                      if (requestId != null) {
                        await RequestService().rejectRequest(requestId);
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        if (requestId != null) {
                          final quote = await requestProviderQuote(
                            context,
                            data,
                          );
                          if (quote == null || !mounted) return;
                          await RequestService().acceptRequest(
                            requestId,
                            serviceFee: quote['serviceFee'] as int,
                            travelFee: quote['travelFee'] as int,
                            extraFee: quote['extraFee'] as int,
                            providerDistanceKm:
                                quote['providerDistanceKm'] as double,
                            quoteNotes: quote['quoteNotes'] as String,
                          );
                          data = Map<String, dynamic>.from(data)
                            ..addAll(quote)
                            ..['dispatchFee'] = quote['travelFee']
                            ..['estimatedCost'] =
                                (quote['serviceFee'] as int) +
                                (quote['travelFee'] as int) +
                                (quote['extraFee'] as int)
                            ..['status'] = 'accepted';
                        }
                        if (!mounted) return;
                        push(
                          context,
                          ProviderActiveJobScreen(
                            requestId: requestId,
                            requestData: data,
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        final activeJobExists = error.toString().contains(
                          'Complete your active job',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              activeJobExists
                                  ? 'Complete your active job before accepting another request.'
                                  : 'This request was cancelled or accepted by another provider.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Review & Quote'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(dashboardTitle),
      actions: [
        _ProviderRequestBadge(services: providerServices),
        IconButton(
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) replace(context, const WelcomeScreen());
          },
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF68A9DF), Color(0xFF4388C7)],
            ),
            borderRadius: BorderRadius.circular(RaRadius.md),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService().watchCurrentProfile(),
            builder: (context, snapshot) {
              final name =
                  snapshot.data?.data()?['displayName'] as String? ??
                  FirebaseAuth.instance.currentUser?.displayName ??
                  'Service Provider';
              return Column(
                children: [
                  Row(
                    children: [
                      _ProviderPresenceAvatar(name: name, online: online),
                      const SizedBox(width: RaSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RaSpace.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: online
                                    ? const Color(0xFFE7F8EF)
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(
                                  RaRadius.pill,
                                ),
                              ),
                              child: Text(
                                online ? 'ACTIVE' : 'OFFLINE',
                                style: TextStyle(
                                  color: online
                                      ? const Color(0xFF087A46)
                                      : Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              online ? providerSpecialty : 'Offline',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: online,
                        onChanged: (value) async {
                          setState(() {
                            online = value;
                            wantsToBeOnline = value;
                          });
                          await AuthService().setProviderOnline(value);
                          if (value) unawaited(_publishProviderLocation());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: RaSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(RaRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: RaSpace.sm),
                        const Text(
                          'Service radius',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          serviceRadius,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        _ProviderRealtimeStats(services: providerServices),
        const SizedBox(height: RaSpace.lg),
        _ProviderNewRequestsBanner(services: providerServices),
        const SizedBox(height: RaSpace.xxl),
        const _ProviderActiveJobsSection(),
        _ProviderServicesOverview(
          services: providerServices,
          serviceRadius: serviceRadius,
          onManage: () => push(context, const ProviderProfileScreen()),
        ),
        const SizedBox(height: RaSpace.xxl),
        const SectionTitle('Incoming Request'),
        const SizedBox(height: RaSpace.md),
        if (!online)
          const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'You are offline',
            message: 'Go online to receive nearby assistance requests.',
          )
        else if (FirebaseAuth.instance.currentUser == null)
          const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a provider to receive assistance requests.',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService().watchOpenRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load requests',
                  message: 'Check your connection and try again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final userId = FirebaseAuth.instance.currentUser!.uid;
              final requests = snapshot.data!.docs.where((request) {
                return _requestMatchesProvider(
                  request.data(),
                  userId,
                  services: providerServices,
                );
              }).toList();
              if (requests.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No new requests',
                  message: 'New requests will appear here in real time.',
                );
              }
              final request = requests.first;
              return requestCard(data: request.data(), requestId: request.id);
            },
          ),
      ],
    ),
  );
}

class ProviderHistoryScreen extends StatefulWidget {
  const ProviderHistoryScreen({super.key});
  @override
  State<ProviderHistoryScreen> createState() => _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState extends State<ProviderHistoryScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider Request History')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RaSpace.xl,
            RaSpace.xl,
            RaSpace.xl,
            RaSpace.md,
          ),
          child: FilterRow(
            selected: filter,
            onSelected: (value) => setState(() => filter = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService().watchProviderRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load history',
                  message: 'Check your connection and try again.',
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final jobs = snapshot.data!.docs.where((job) {
                final status = job.data()['status'] as String? ?? '';
                if (filter == 1) return status == 'completed';
                if (filter == 2)
                  return status == 'cancelled' || status == 'rejected';
                return status == 'completed' ||
                    status == 'cancelled' ||
                    status == 'rejected';
              }).toList();
              if (jobs.isEmpty)
                return EmptyState(
                  icon: Icons.history_outlined,
                  title: filter == 0
                      ? 'No job history'
                      : filter == 1
                      ? 'No completed jobs'
                      : 'No cancelled jobs',
                  message:
                      'Matching provider jobs will appear here automatically.',
                );
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  RaSpace.xl,
                  RaSpace.sm,
                  RaSpace.xl,
                  RaSpace.xl,
                ),
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: RaSpace.md),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final data = job.data();
                  final created = (data['createdAt'] as Timestamp?)?.toDate();
                  final date = created == null
                      ? 'Date unavailable'
                      : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                  final vehicle = [data['modelYear'], data['registration']]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' - ');
                  return ProviderJobCard(
                    driver: data['driverName'] as String? ?? 'Driver',
                    vehicle: vehicle.isEmpty
                        ? data['vehicleType'] as String? ?? 'Vehicle'
                        : vehicle,
                    service: data['issue'] as String? ?? 'Roadside assistance',
                    date: date,
                    location:
                        data['locationLabel'] as String? ?? 'Pinned location',
                    cost:
                        'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    completed: data['status'] == 'completed',
                    onViewDetails: () => push(
                      context,
                      ProviderRequestDetailsScreen(
                        requestId: job.id,
                        data: data,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderRatingSummary extends StatelessWidget {
  const _ProviderRatingSummary();

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchProviderRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineMessage(
            icon: Icons.star_outline_rounded,
            text: 'Unable to load driver ratings.',
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final ratings = snapshot.data!.docs
            .map((request) => request.data()['driverRating'])
            .whereType<num>()
            .map((rating) => rating.toDouble())
            .toList();
        if (ratings.isEmpty) {
          return const InlineMessage(
            icon: Icons.star_outline_rounded,
            text: 'No ratings yet. Completed job ratings will appear here.',
          );
        }
        final average = ratings.reduce((a, b) => a + b) / ratings.length;
        final fiveStarCount = ratings.where((rating) => rating == 5).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: raGoldPale,
                    borderRadius: BorderRadius.circular(RaRadius.md),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: raGold,
                    size: 36,
                  ),
                ),
                const SizedBox(width: RaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: RaText.numeric.copyWith(fontSize: 26),
                      ),
                      Text(
                        '${ratings.length} driver ${ratings.length == 1 ? 'review' : 'reviews'}',
                        style: RaText.bodyMuted,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$fiveStarCount', style: RaText.numeric),
                    const Text('5-star', style: RaText.caption),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
      await AuthService().updateCurrentProfile({
        'workingHours': hours,
        'serviceRadius': radius,
      });
      await AuthService().syncProviderDirectory();
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

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.draft, this.requestId});
  final RequestDraft draft;
  final String? requestId;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  int status = 0;
  LatLng providerPosition = MapMock.providerPoint;
  String providerName = 'Service Provider';
  String providerPhone = '';
  int estimatedCost = 0;
  bool cancelled = false;
  bool hasProviderLocation = false;
  String? requestError;
  RoadRoute? roadRoute;
  bool routeLoading = false;
  int routeRequestVersion = 0;
  final statuses = const ['Accepted', 'En Route', 'Arrived', 'Completed'];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestListener;

  Future<void> refreshRoadRoute(LatLng origin) async {
    final version = ++routeRequestVersion;
    if (mounted) setState(() => routeLoading = true);
    try {
      final result = await const RouteService().fetchDrivingRoute(
        origin: origin,
        destination: LatLng(widget.draft.latitude, widget.draft.longitude),
      );
      if (!mounted || version != routeRequestVersion) return;
      setState(() {
        roadRoute = result;
        routeLoading = false;
      });
    } catch (_) {
      if (!mounted || version != routeRequestVersion) return;
      setState(() {
        routeLoading = false;
        requestError = 'Road route ETA is temporarily unavailable.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      requestListener = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final value = snapshot.data()?['status'] as String?;
              final data = snapshot.data();
              final latitude = (data?['providerLatitude'] as num?)?.toDouble();
              final longitude = (data?['providerLongitude'] as num?)
                  ?.toDouble();
              final updatedPosition = latitude != null && longitude != null
                  ? LatLng(latitude, longitude)
                  : null;
              final shouldRefreshRoute =
                  updatedPosition != null &&
                  (!hasProviderLocation ||
                      Geolocator.distanceBetween(
                            providerPosition.latitude,
                            providerPosition.longitude,
                            updatedPosition.latitude,
                            updatedPosition.longitude,
                          ) >=
                          20);
              final next = switch (value) {
                'accepted' => 0,
                'en_route' => 1,
                'arrived' => 2,
                'completed' => 3,
                _ => status,
              };
              if (mounted) {
                setState(() {
                  status = next;
                  cancelled = value == 'cancelled';
                  requestError = null;
                  providerName =
                      data?['providerName'] as String? ?? providerName;
                  providerPhone =
                      data?['providerPhone'] as String? ?? providerPhone;
                  estimatedCost =
                      (data?['estimatedCost'] as num?)?.toInt() ??
                      estimatedCost;
                  if (updatedPosition != null) {
                    providerPosition = updatedPosition;
                    hasProviderLocation = true;
                  }
                });
                if (shouldRefreshRoute) {
                  unawaited(refreshRoadRoute(updatedPosition));
                }
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  requestError = 'Live updates are temporarily unavailable.';
                });
              }
            },
          );
    } else {
      requestError = 'This request is not connected to live tracking.';
    }
  }

  @override
  void dispose() {
    requestListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Track Assistance'),
      actions: [
        IconButton(
          onPressed: () => push(context, const EmergencyScreen()),
          tooltip: 'Emergency contact',
          style: IconButton.styleFrom(
            backgroundColor: raDangerPale,
            foregroundColor: raDanger,
          ),
          icon: const Icon(Icons.sos_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RaSpace.xl),
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RaRadius.md),
                      child: SizedBox(
                        height: 280,
                        child: MapMock(
                          position: LatLng(
                            widget.draft.latitude,
                            widget.draft.longitude,
                          ),
                          providerPosition: providerPosition,
                          routePoints: roadRoute?.points,
                          showProviders: hasProviderLocation,
                          showRoute: roadRoute != null,
                        ),
                      ),
                    ),
                    Positioned(
                      left: RaSpace.sm,
                      right: RaSpace.sm,
                      top: RaSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RaSpace.md,
                          vertical: RaSpace.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(RaRadius.sm),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0C285F),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_searching,
                              color: raBlue,
                              size: 20,
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Expanded(
                              child: Text(
                                cancelled
                                    ? 'Request cancelled'
                                    : status == 3
                                    ? 'Assistance completed'
                                    : hasProviderLocation
                                    ? roadRoute == null
                                          ? 'Calculating road route...'
                                          : roadRoute!.trafficAware
                                          ? 'Live traffic route'
                                          : 'Fastest driving route'
                                    : 'Waiting for provider location',
                                style: RaText.title,
                              ),
                            ),
                            if (!cancelled && status < 3 && roadRoute != null)
                              Text(
                                '${roadRoute!.distanceKm.toStringAsFixed(1)} km · ${roadRoute!.durationMinutes} min',
                                style: RaText.caption.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (requestError != null && !routeLoading)
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: raDanger,
                                size: 19,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RaSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RaSpace.md),
                    child: Row(
                      children: [
                        ProfileInitials(name: providerName, radius: 24),
                        const SizedBox(width: RaSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(providerName, style: RaText.title),
                              const SizedBox(height: 2),
                              Text(
                                providerPhone.isEmpty
                                    ? 'RoadAssist Service Provider'
                                    : providerPhone,
                                style: RaText.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: providerPhone.isEmpty
                              ? null
                              : () => showCallPrompt(
                                  context,
                                  name: providerName,
                                  number: providerPhone,
                                ),
                          tooltip: 'Call',
                          icon: const Icon(Icons.call_outlined),
                        ),
                        const SizedBox(width: RaSpace.xs),
                        IconButton.filledTonal(
                          onPressed: widget.requestId == null
                              ? null
                              : () => push(
                                  context,
                                  ChatScreen(
                                    requestId: widget.requestId,
                                    peerName: providerName,
                                    peerPhone: providerPhone,
                                  ),
                                ),
                          tooltip: 'Chat',
                          icon: _UnreadChatIcon(
                            requestId: widget.requestId,
                            seenField: 'driverMessagesSeenAt',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                Text(
                  cancelled
                      ? 'Request cancelled'
                      : status == 0
                      ? 'Provider accepted your request'
                      : status == 1
                      ? 'Provider is on the way'
                      : status == 2
                      ? 'Provider has arrived'
                      : 'Assistance completed',
                  style: RaText.headline,
                ),
                if (requestError != null) ...[
                  const SizedBox(height: RaSpace.xs),
                  Text(
                    requestError!,
                    style: RaText.bodyMuted.copyWith(color: raDanger),
                  ),
                ],
                const SizedBox(height: RaSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: RaSpace.lg,
                    ),
                    child: StatusTimeline(statuses: statuses, current: status),
                  ),
                ),
                const SizedBox(height: RaSpace.md),
                InfoStrip(
                  icon: Icons.receipt_long_outlined,
                  title: 'Request ${widget.requestId ?? 'Not available'}',
                  value: '${widget.draft.issue} - Estimated Rs. $estimatedCost',
                ),
              ],
            ),
          ),
          BottomAction(
            label: cancelled
                ? 'Back to Home'
                : widget.requestId != null && status < 3
                ? 'Waiting for provider update'
                : status == 3
                ? 'Back to Home'
                : 'Live tracking unavailable',
            enabled: cancelled || status == 3,
            onTap: () {
              if (cancelled || status == 3) {
                replace(context, const DriverShell());
              }
            },
          ),
        ],
      ),
    ),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.requestId,
    this.peerName = 'Service Provider',
    this.peerPhone = '',
  });
  final String? requestId;
  final String peerName;
  final String peerPhone;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

Future<Map<String, dynamic>?> requestProviderQuote(
  BuildContext context,
  Map<String, dynamic> requestData,
) async {
  var distanceKm = 0.0;
  final driverLatitude = (requestData['latitude'] as num?)?.toDouble();
  final driverLongitude = (requestData['longitude'] as num?)?.toDouble();
  if (driverLatitude != null && driverLongitude != null) {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final providerPosition = await Geolocator.getCurrentPosition();
        distanceKm =
            Geolocator.distanceBetween(
              providerPosition.latitude,
              providerPosition.longitude,
              driverLatitude,
              driverLongitude,
            ) /
            1000;
      }
    } catch (_) {
      // The provider can still enter a manual travel charge without GPS.
    }
  }
  if (!context.mounted) return null;

  final serviceController = TextEditingController(
    text: '${(requestData['serviceFee'] as num?)?.toInt() ?? 0}',
  );
  final suggestedTravel = distanceKm > 0
      ? (distanceKm * 100).ceil()
      : (requestData['dispatchFee'] as num?)?.toInt() ?? 0;
  final travelController = TextEditingController(text: '$suggestedTravel');
  final extraController = TextEditingController(text: '0');
  final notesController = TextEditingController();

  int amount(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final total =
            amount(serviceController) +
            amount(travelController) +
            amount(extraController);
        Widget moneyField(String label, TextEditingController controller) =>
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
            );
        return AlertDialog(
          icon: const Icon(Icons.request_quote_outlined, color: raBlue),
          title: const Text('Review and quote request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${requestData['issue'] ?? 'Roadside assistance'} - ${distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km away' : 'distance unavailable'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: RaSpace.md),
                moneyField('Service charge', serviceController),
                const SizedBox(height: RaSpace.sm),
                moneyField('Travel / distance charge', travelController),
                const SizedBox(height: RaSpace.sm),
                moneyField('Extra charge', extraController),
                const SizedBox(height: RaSpace.sm),
                TextField(
                  controller: notesController,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Quote notes (optional)',
                    hintText: 'Parts, after-hours fee, or other details',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(RaSpace.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(RaRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quoted total', style: RaText.label),
                      Text('Rs. $total', style: RaText.title),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: total <= 0
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'serviceFee': amount(serviceController),
                      'travelFee': amount(travelController),
                      'extraFee': amount(extraController),
                      'providerDistanceKm': distanceKm,
                      'quoteNotes': notesController.text.trim(),
                    }),
              child: const Text('Accept with Quote'),
            ),
          ],
        );
      },
    ),
  );
  serviceController.dispose();
  travelController.dispose();
  extraController.dispose();
  notesController.dispose();
  return result;
}

class _UnreadChatIcon extends StatelessWidget {
  const _UnreadChatIcon({required this.requestId, required this.seenField});

  final String? requestId;
  final String seenField;

  @override
  Widget build(BuildContext context) {
    if (requestId == null || !signedIn) {
      return const Icon(Icons.chat_outlined);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: RequestService().watchRequest(requestId!),
      builder: (context, requestSnapshot) {
        final seenAt = requestSnapshot.data?.data()?[seenField] as Timestamp?;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: RequestService().watchMessages(requestId!),
          builder: (context, messageSnapshot) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final unread =
                messageSnapshot.data?.docs.where((message) {
                  final data = message.data();
                  if (data['senderId'] == currentUserId) return false;
                  final createdAt = data['createdAt'] as Timestamp?;
                  return seenAt == null ||
                      createdAt == null ||
                      createdAt.compareTo(seenAt) > 0;
                }).length ??
                0;
            return Badge(
              isLabelVisible: unread > 0,
              backgroundColor: raDanger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.chat_outlined),
            );
          },
        );
      },
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? messageListener;
  final messages = <String>[];
  final senderIds = <String>[];
  final messageImages = <String?>[];
  bool attachingPhoto = false;

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      unawaited(RequestService().markChatSeen(widget.requestId!));
      messageListener = RequestService()
          .watchMessages(widget.requestId!)
          .listen((snapshot) {
            if (!mounted) return;
            setState(() {
              messages
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['text'] as String? ?? '',
                  ),
                );
              senderIds
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['senderId'] as String? ?? '',
                  ),
                );
              messageImages
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => doc.data()['imageData'] as String?,
                  ),
                );
            });
            unawaited(RequestService().markChatSeen(widget.requestId!));
          });
    }
  }

  @override
  void dispose() {
    messageListener?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> attachPhoto() async {
    if (widget.requestId == null || attachingPhoto) return;
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
            imageQuality: 75,
            maxWidth: 1400,
          );
    if (photo == null || !mounted) return;
    setState(() => attachingPhoto = true);
    try {
      final imageData = await PhotoUploadService().prepareChatPhoto(photo);
      await RequestService().sendChatPhoto(widget.requestId!, imageData);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to send photo: $error')));
      }
    } finally {
      if (mounted) setState(() => attachingPhoto = false);
    }
  }

  Future<void> shareCurrentLocation() async {
    if (widget.requestId == null) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission denied.');
      }
      final position = await Geolocator.getCurrentPosition();
      final mapLink =
          'Current location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      await RequestService().sendMessage(widget.requestId!, mapLink);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share current location.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.peerName),
      actions: [
        IconButton(
          onPressed: widget.peerPhone.isEmpty
              ? null
              : () => showCallPrompt(
                  context,
                  name: widget.peerName,
                  number: widget.peerPhone,
                ),
          tooltip: 'Call ${widget.peerName}',
          icon: const Icon(Icons.call_outlined),
        ),
        const SizedBox(width: RaSpace.sm),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(RaSpace.xl),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final mine = widget.requestId == null
                    ? index.isOdd
                    : senderIds[index] ==
                          FirebaseAuth.instance.currentUser?.uid;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    margin: const EdgeInsets.only(bottom: RaSpace.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaSpace.md,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? raBlue : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(RaRadius.sm),
                        topRight: const Radius.circular(RaRadius.sm),
                        bottomLeft: Radius.circular(mine ? RaRadius.sm : 3),
                        bottomRight: Radius.circular(mine ? 3 : RaRadius.sm),
                      ),
                      border: mine ? null : Border.all(color: raLine),
                    ),
                    child: messageImages[index] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              RaRadius.sm - 2,
                            ),
                            child: Image.memory(
                              base64Decode(messageImages[index]!),
                              width: 220,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            messages[index],
                            style: TextStyle(
                              color: mine ? Colors.white : raInk,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.sm,
              RaSpace.sm,
              RaSpace.sm,
              RaSpace.md,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: raLine)),
            ),
            child: Column(
              children: [
                if (widget.requestId != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.my_location_outlined, size: 16),
                      label: const Text('Share current location'),
                      onPressed: shareCurrentLocation,
                    ),
                  ),
                  const SizedBox(height: RaSpace.xs),
                ],
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.requestId == null || attachingPhoto
                          ? null
                          : attachPhoto,
                      tooltip: 'Attach photo',
                      icon: attachingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RaSpace.xs),
                    IconButton.filled(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        controller.clear();
                        if (widget.requestId != null) {
                          await RequestService().sendMessage(
                            widget.requestId!,
                            text,
                          );
                        } else {
                          setState(() {
                            messages.add(text);
                            senderIds.add('driver');
                            messageImages.add(null);
                          });
                        }
                      },
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ProviderActiveJobScreen extends StatefulWidget {
  const ProviderActiveJobScreen({
    super.key,
    this.requestId,
    this.requestData = const {},
  });
  final String? requestId;
  final Map<String, dynamic> requestData;
  @override
  State<ProviderActiveJobScreen> createState() =>
      _ProviderActiveJobScreenState();
}

class _ProviderActiveJobScreenState extends State<ProviderActiveJobScreen> {
  int status = 0;
  final statuses = const ['Accepted', 'En Route', 'Arrived', 'Completed'];
  StreamSubscription<Position>? locationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  requestSubscription;
  late Map<String, dynamic> requestData;
  bool updatingStatus = false;
  bool requestCancelled = false;
  String? locationMessage;
  LatLng? currentProviderPosition;
  RoadRoute? roadRoute;
  int routeRequestVersion = 0;
  final serviceNotesController = TextEditingController();
  List<String> servicePhotos = <String>[];
  bool savingDocumentation = false;

  static const backendStatuses = [
    'accepted',
    'en_route',
    'arrived',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    requestData = Map<String, dynamic>.from(widget.requestData);
    status = backendStatuses.indexOf(
      requestData['status'] as String? ?? 'accepted',
    );
    requestCancelled = requestData['status'] == 'cancelled';
    serviceNotesController.text = requestData['serviceNotes'] as String? ?? '';
    servicePhotos =
        (requestData['servicePhotoData'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    if (status < 0) status = 0;
    if (widget.requestId != null) {
      requestSubscription = RequestService()
          .watchRequest(widget.requestId!)
          .listen(
            (snapshot) {
              final data = snapshot.data();
              if (!mounted || data == null) return;
              final nextStatus = backendStatuses.indexOf(
                data['status'] as String? ?? '',
              );
              setState(() {
                requestData = data;
                requestCancelled = data['status'] == 'cancelled';
                if (nextStatus >= 0) status = nextStatus;
                servicePhotos =
                    (data['servicePhotoData'] as List<dynamic>? ?? const [])
                        .whereType<String>()
                        .toList();
              });
            },
            onError: (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to receive live request updates.'),
                  ),
                );
              }
            },
          );
    }
    startLocationSharing();
  }

  Future<void> startLocationSharing() async {
    if (widget.requestId == null) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          locationMessage =
              'Location permission is required to share your live position.';
        });
      }
      return;
    }
    locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        ).listen(
          (position) {
            if (mounted) {
              setState(() {
                currentProviderPosition = LatLng(
                  position.latitude,
                  position.longitude,
                );
                locationMessage = null;
              });
            }
            unawaited(
              refreshProviderRoute(
                LatLng(position.latitude, position.longitude),
              ),
            );
            RequestService().updateProviderLocation(
              widget.requestId!,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          },
          onError: (_) {
            if (mounted) {
              setState(
                () => locationMessage = 'Live location sharing stopped.',
              );
            }
          },
        );
  }

  Future<void> refreshProviderRoute(LatLng origin) async {
    final latitude = (requestData['latitude'] as num?)?.toDouble();
    final longitude = (requestData['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    final version = ++routeRequestVersion;
    try {
      final result = await const RouteService().fetchDrivingRoute(
        origin: origin,
        destination: LatLng(latitude, longitude),
      );
      if (!mounted || version != routeRequestVersion) return;
      setState(() => roadRoute = result);
    } catch (_) {
      if (!mounted || version != routeRequestVersion) return;
      setState(() => locationMessage = 'Road route ETA is unavailable.');
    }
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    requestSubscription?.cancel();
    serviceNotesController.dispose();
    super.dispose();
  }

  Future<void> addDocumentationPhoto() async {
    if (servicePhotos.length >= 3 || widget.requestId == null) return;
    final navigator = Navigator.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => const SafeArea(
        child: Wrap(
          children: [
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              source: ImageSource.camera,
            ),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              source: ImageSource.gallery,
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
            imageQuality: 70,
            maxWidth: 1200,
          );
    if (photo == null || !mounted) return;
    setState(() => savingDocumentation = true);
    try {
      final encoded = await PhotoUploadService().prepareVehiclePhoto(photo);
      final updated = [...servicePhotos, encoded];
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: updated,
      );
      if (mounted) setState(() => servicePhotos = updated);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add documentation: $error')),
        );
    } finally {
      if (mounted) setState(() => savingDocumentation = false);
    }
  }

  Future<void> saveDocumentation() async {
    if (widget.requestId == null || savingDocumentation) return;
    setState(() => savingDocumentation = true);
    try {
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: servicePhotos,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service documentation saved.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save notes: $error')));
    } finally {
      if (mounted) setState(() => savingDocumentation = false);
    }
  }

  Future<void> removeDocumentationPhoto(int index) async {
    if (widget.requestId == null || savingDocumentation) return;
    final updated = [...servicePhotos]..removeAt(index);
    setState(() => servicePhotos = updated);
    try {
      await RequestService().updateProviderDocumentation(
        widget.requestId!,
        serviceNotes: serviceNotesController.text,
        servicePhotoData: updated,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove the photo.')),
        );
      }
    }
  }

  Future<void> advanceStatus() async {
    if (updatingStatus || widget.requestId == null || requestCancelled) return;
    if (status == 3) {
      replace(
        context,
        ProviderCompletedScreen(
          requestId: widget.requestId!,
          requestData: requestData,
        ),
      );
      return;
    }
    int? finalCost;
    if (status == 2) {
      finalCost = await requestFinalCost();
      if (finalCost == null || !mounted) return;
    }
    setState(() => updatingStatus = true);
    try {
      if (status == 2) {
        await RequestService().updateProviderDocumentation(
          widget.requestId!,
          serviceNotes: serviceNotesController.text,
          servicePhotoData: servicePhotos,
        );
        await RequestService().completeProviderJob(
          widget.requestId!,
          finalCost!,
        );
        if (mounted) {
          final completedData = Map<String, dynamic>.from(requestData)
            ..['finalCost'] = finalCost
            ..['status'] = 'completed'
            ..['serviceNotes'] = serviceNotesController.text.trim()
            ..['servicePhotoData'] = servicePhotos;
          replace(
            context,
            ProviderCompletedScreen(
              requestId: widget.requestId!,
              requestData: completedData,
            ),
          );
        }
      } else {
        await RequestService().advanceProviderStatus(
          widget.requestId!,
          backendStatuses[status + 1],
        );
        try {
          await RequestService().updateProviderDocumentation(
            widget.requestId!,
            serviceNotes: serviceNotesController.text,
            servicePhotoData: servicePhotos,
          );
        } catch (_) {
          // Status progression must not be blocked by an optional notes save.
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update job status: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => updatingStatus = false);
    }
  }

  Future<int?> requestFinalCost() async {
    final estimate = (requestData['estimatedCost'] as num?)?.toInt() ?? 0;
    final controller = TextEditingController(text: '$estimate');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.receipt_long_outlined, color: raBlue),
        title: const Text('Confirm final charge'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Final amount (Rs.)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Complete Job'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return null;
    final amount = int.tryParse(value.replaceAll(',', '').trim());
    if (amount == null || amount < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid final amount.')),
        );
      }
      return null;
    }
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    final data = requestData;
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final driverName = data['driverName'] as String? ?? 'Nearby Driver';
    final driverPhone = data['driverPhone'] as String? ?? '';
    final vehicle = [
      data['vehicleType'] as String? ?? '',
      data['modelYear'] as String? ?? '',
      data['registration'] as String? ?? '',
    ].where((value) => value.isNotEmpty).join(' - ');
    return Scaffold(
      appBar: AppBar(title: const Text('Active Assistance')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  Container(
                    padding: const EdgeInsets.all(RaSpace.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF397DBD), Color(0xFF2F6FAE)],
                      ),
                      borderRadius: BorderRadius.circular(RaRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CURRENT STATUS',
                              style: RaText.eyebrowOnDark,
                            ),
                            const Spacer(),
                            StatusPill(
                              label: requestCancelled ? 'CANCELLED' : 'LIVE',
                              tone: requestCancelled
                                  ? RaTone.danger
                                  : RaTone.warning,
                              dot: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.sm),
                        Row(
                          children: [
                            Icon(
                              status == 0
                                  ? Icons.task_alt
                                  : status == 1
                                  ? Icons.local_shipping_outlined
                                  : status == 2
                                  ? Icons.location_on_outlined
                                  : Icons.verified_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: RaSpace.sm),
                            Text(
                              requestCancelled
                                  ? 'Request Cancelled'
                                  : statuses[status],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RaSpace.lg),
                        Container(
                          padding: const EdgeInsets.all(RaSpace.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(RaRadius.sm),
                          ),
                          child: StatusTimeline(
                            statuses: statuses,
                            current: status,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RaRadius.md),
                    child: SizedBox(
                      height: 250,
                      child: MapMock(
                        position: LatLng(latitude, longitude),
                        providerPosition: currentProviderPosition,
                        routePoints: roadRoute?.points,
                        showProviders: currentProviderPosition != null,
                        showRoute: roadRoute != null,
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => openMapNavigation(
                        context,
                        latitude: latitude,
                        longitude: longitude,
                      ),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Start Voice Navigation'),
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        children: [
                          SummaryRow('Driver', driverName),
                          SummaryRow(
                            'Vehicle',
                            vehicle.isEmpty
                                ? 'Vehicle details unavailable'
                                : vehicle,
                          ),
                          SummaryRow(
                            'Breakdown',
                            data['issue'] as String? ?? 'Roadside assistance',
                          ),
                          SummaryRow(
                            'Location',
                            data['locationLabel'] as String? ??
                                'Pinned location',
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: driverPhone.isEmpty
                                      ? null
                                      : () => showCallPrompt(
                                          context,
                                          name: driverName,
                                          number: driverPhone,
                                        ),
                                  icon: const Icon(Icons.call),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: RaSpace.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.requestId == null
                                      ? null
                                      : () => push(
                                          context,
                                          ChatScreen(
                                            requestId: widget.requestId,
                                            peerName: driverName,
                                            peerPhone: driverPhone,
                                          ),
                                        ),
                                  icon: _UnreadChatIcon(
                                    requestId: widget.requestId,
                                    seenField: 'providerMessagesSeenAt',
                                  ),
                                  label: const Text('Chat'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  if (locationMessage != null) ...[
                    InlineMessage(
                      icon: Icons.location_off_outlined,
                      text: locationMessage!,
                    ),
                    const SizedBox(height: RaSpace.lg),
                  ],
                  InfoStrip(
                    icon: currentProviderPosition == null
                        ? Icons.location_searching
                        : Icons.share_location_outlined,
                    title: currentProviderPosition == null
                        ? 'Finding your live location'
                        : 'Live location sharing active',
                    value: currentProviderPosition == null
                        ? 'Allow location access and keep this page open.'
                        : roadRoute == null
                        ? 'Calculating the fastest driving route...'
                        : '${roadRoute!.distanceKm.toStringAsFixed(1)} km by road · ${roadRoute!.durationMinutes} min${roadRoute!.trafficAware ? ' with live traffic' : ''}',
                  ),
                  const SizedBox(height: RaSpace.lg),
                  if (requestCancelled) ...[
                    const InlineMessage(
                      icon: Icons.cancel_outlined,
                      text: 'The driver cancelled this assistance request.',
                    ),
                    const SizedBox(height: RaSpace.lg),
                  ],
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Documentation', style: RaText.headline),
                      ),
                      Text(
                        '${servicePhotos.length}/3 added',
                        style: RaText.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.md),
                  SizedBox(
                    height: 105,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (servicePhotos.length < 3)
                          InkWell(
                            onTap: savingDocumentation
                                ? null
                                : addDocumentationPhoto,
                            borderRadius: BorderRadius.circular(RaRadius.md),
                            child: Container(
                              width: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  RaRadius.md,
                                ),
                                border: Border.all(
                                  color: raBlue,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  savingDocumentation
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: raBlue,
                                        ),
                                  const SizedBox(height: 6),
                                  const Text('Add Photo', style: RaText.label),
                                ],
                              ),
                            ),
                          ),
                        for (
                          var index = 0;
                          index < servicePhotos.length;
                          index++
                        ) ...[
                          if (index > 0 || servicePhotos.length < 3)
                            const SizedBox(width: RaSpace.sm),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  RaRadius.md,
                                ),
                                child: Image.memory(
                                  base64Decode(servicePhotos[index]),
                                  width: 122,
                                  height: 105,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(28, 28),
                                    padding: EdgeInsets.zero,
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      removeDocumentationPhoto(index),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  const Text('Service Notes', style: RaText.headline),
                  const SizedBox(height: RaSpace.sm),
                  TextField(
                    controller: serviceNotesController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'Add arrival notes, work completed or important observations...',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: savingDocumentation ? null : saveDocumentation,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Notes'),
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                ],
              ),
            ),
            BottomAction(
              label: updatingStatus
                  ? 'Updating status...'
                  : requestCancelled
                  ? 'Back to Dashboard'
                  : status == 3
                  ? 'Finish Job'
                  : 'Mark as ${statuses[status + 1]}',
              enabled: !updatingStatus && widget.requestId != null,
              onTap: requestCancelled
                  ? () => replace(context, const ProviderShell())
                  : advanceStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderCompletedScreen extends StatelessWidget {
  const ProviderCompletedScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });
  final String requestId;
  final Map<String, dynamic> requestData;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.xxl),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: raSuccessPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 50, color: raSuccess),
            ),
            const SizedBox(height: RaSpace.xl),
            const Text(
              'Assistance Completed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: raNavy,
              ),
            ),
            const SizedBox(height: RaSpace.xs),
            Text(
              'Request $requestId has been marked as completed.',
              textAlign: TextAlign.center,
              style: RaText.bodyMuted,
            ),
            const SizedBox(height: RaSpace.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(RaSpace.lg),
                child: Column(
                  children: [
                    SummaryRow(
                      'Service',
                      requestData['issue'] as String? ?? 'Roadside assistance',
                    ),
                    SummaryRow(
                      'Driver',
                      requestData['driverName'] as String? ?? 'Driver',
                    ),
                    SummaryRow(
                      'Vehicle',
                      [requestData['modelYear'], requestData['registration']]
                              .whereType<String>()
                              .where((value) => value.trim().isNotEmpty)
                              .join(' - ')
                              .isEmpty
                          ? 'Not provided'
                          : [
                                  requestData['modelYear'],
                                  requestData['registration'],
                                ]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' - '),
                    ),
                    SummaryRow(
                      'Location',
                      requestData['locationLabel'] as String? ??
                          'Pinned location',
                    ),
                    if ((requestData['serviceNotes'] as String? ?? '')
                        .trim()
                        .isNotEmpty)
                      SummaryRow(
                        'Service Notes',
                        requestData['serviceNotes'] as String,
                      ),
                    const Divider(),
                    SummaryRow(
                      'Final Cost',
                      'Rs. ${requestData['finalCost'] ?? requestData['estimatedCost'] ?? 0}',
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => replace(context, const ProviderShell()),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// SHARED — STATUS & TIMELINE
// ============================================================

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.statuses,
    required this.current,
  });
  final List<String> statuses;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(
      statuses.length,
      (index) => Expanded(
        child: Column(
          children: [
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index <= current ? raBlue : raLine,
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: index < current
                        ? raBlue
                        : index == current
                        ? Colors.white
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index <= current ? raBlue : raLine,
                      width: index == current ? 2.4 : 1.6,
                    ),
                  ),
                  child: index < current
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : index == current
                      ? const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: raBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                if (index < statuses.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index < current ? raBlue : raLine,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: RaSpace.sm),
            Text(
              statuses[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: index == current
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: index <= current ? raInk : raFaint,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProviderStat extends StatelessWidget {
  const ProviderStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: RaSpace.md,
        horizontal: RaSpace.sm,
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: raBlue, size: 18),
            const SizedBox(height: 6),
          ],
          Text(value, style: RaText.numeric),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: RaText.caption.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    ),
  );
}

class DriverRequestDetailsScreen extends StatelessWidget {
  const DriverRequestDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request Details')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.md),
          decoration: BoxDecoration(
            color: raSuccessPale,
            borderRadius: BorderRadius.circular(RaRadius.sm),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: raSuccess),
              SizedBox(width: RaSpace.sm),
              Expanded(
                child: Text(
                  'Service completed successfully',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: raSuccess,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.md),
        const InfoStrip(
          icon: Icons.receipt_long_outlined,
          title: 'Request RA-8829-XJ',
          value: '25 Aug 2026 - 02:30 PM',
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              children: const [
                SummaryRow('Assistance Type', 'Flat Tyre Repair'),
                SummaryRow('Vehicle', 'Toyota Premio - WP CAS 8822'),
                SummaryRow('Pickup Location', 'Galle Road, Colombo 03'),
                SummaryRow('Provider', 'Kasun Jayawardena'),
                Divider(),
                SummaryRow('Service Fee', 'Rs. 1,500'),
                SummaryRow('Distance Charge', 'Rs. 850'),
                SummaryRow('Emergency Charge', 'Rs. 500'),
                Divider(),
                SummaryRow('Total Paid', 'Rs. 2,850', strong: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.xl),
        const Text('Request Timeline', style: RaText.headline),
        const SizedBox(height: RaSpace.md),
        const DetailTimeline(),
        const SizedBox(height: RaSpace.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    icon: const Icon(Icons.receipt_long, color: raBlue),
                    title: const Text('Receipt RA-8829-XJ'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SummaryRow('Service', 'Flat Tyre Repair'),
                        SummaryRow('Provider', 'Kasun Jayawardena'),
                        SummaryRow('Date', '25 Aug 2026 - 02:30 PM'),
                        Divider(),
                        SummaryRow('Total Paid', 'Rs. 2,850', strong: true),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Receipt'),
              ),
            ),
            const SizedBox(width: RaSpace.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) {
                    var rating = 0;
                    return StatefulBuilder(
                      builder: (context, setSheetState) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Rate your service',
                                style: RaText.headline,
                              ),
                              const SizedBox(height: RaSpace.sm),
                              const Text(
                                'How was your roadside assistance?',
                                style: RaText.bodyMuted,
                              ),
                              const SizedBox(height: RaSpace.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (index) => IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                    ),
                                    onPressed: () =>
                                        setSheetState(() => rating = index + 1),
                                    icon: Icon(
                                      index < rating
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: raGold,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: RaSpace.md),
                              FilledButton(
                                onPressed: rating == 0
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Thank you for your $rating-star rating.',
                                            ),
                                          ),
                                        );
                                        Navigator.pop(sheetContext);
                                      },
                                child: const Text('Submit Rating'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate Service'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ProviderCaseDetailsScreen extends StatelessWidget {
  const ProviderCaseDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Case Details')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        const InfoStrip(
          icon: Icons.person_outline,
          title: 'Rajesh Kumar',
          value: '+94 77 123 4567 - Premium Member',
        ),
        const SizedBox(height: RaSpace.md),
        const InfoStrip(
          icon: Icons.directions_car_outlined,
          title: 'Toyota Innova',
          value: 'WP CAB 1234 - White',
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                FormSectionTitle(
                  Icons.warning_amber_outlined,
                  'Incident Details',
                ),
                SizedBox(height: RaSpace.md),
                SummaryRow('Breakdown Type', 'Flat Tyre Repair'),
                SummaryRow('Location', 'Galle Road, Colombo 03'),
                SummaryRow(
                  'Customer Notes',
                  'Rear tyre is punctured. Vehicle is safely parked.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(RaRadius.md),
          child: const SizedBox(
            height: 220,
            child: MapMock(showProviders: true, showRoute: true),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(RaSpace.lg),
            child: Column(
              children: [
                SummaryRow('Service Date', '25 Aug 2026 - 02:30 PM'),
                SummaryRow('Final Cost', 'Rs. 2,850', strong: true),
                SummaryRow('Status', 'Completed'),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        OutlinedButton.icon(
          onPressed: () => showCallPrompt(
            context,
            name: 'Rajesh Kumar',
            number: '+94 77 845 2210',
          ),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Contact Customer'),
        ),
      ],
    ),
  );
}

class GpsIssueScreen extends StatefulWidget {
  const GpsIssueScreen({super.key});
  @override
  State<GpsIssueScreen> createState() => _GpsIssueScreenState();
}

class _GpsIssueScreenState extends State<GpsIssueScreen> {
  bool retrying = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Location Issue')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(RaSpace.md),
          decoration: BoxDecoration(
            color: raGoldPale,
            borderRadius: BorderRadius.circular(RaRadius.sm),
            border: Border.all(color: raGold.withValues(alpha: 0.4)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: raGold),
              SizedBox(width: RaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Location Accuracy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A4A00),
                      ),
                    ),
                    Text(
                      "We're having trouble pinpointing your exact location. This might delay help arriving.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF7A4A00)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(RaRadius.md),
          child: const SizedBox(height: 340, child: MapMock()),
        ),
        const SizedBox(height: RaSpace.xl),
        FilledButton.icon(
          onPressed: () async {
            setState(() => retrying = true);
            await Future<void>.delayed(const Duration(seconds: 1));
            if (mounted) setState(() => retrying = false);
          },
          icon: retrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh),
          label: Text(retrying ? 'Finding Location...' : 'Try Again'),
        ),
        const SizedBox(height: RaSpace.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Adjust Manually'),
        ),
        const SizedBox(height: RaSpace.sm),
        const Text(
          'Please refine your location before continuing.',
          textAlign: TextAlign.center,
          style: RaText.caption,
        ),
      ],
    ),
  );
}

class DetailTimeline extends StatelessWidget {
  const DetailTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Request submitted', '02:18 PM'),
      ('Provider accepted', '02:21 PM'),
      ('Provider arrived', '02:34 PM'),
      ('Service completed', '02:52 PM'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.lg),
        child: Column(
          children: List.generate(
            entries.length,
            (index) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: raSuccess,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    if (index < entries.length - 1)
                      Container(width: 2, height: 32, color: raLine),
                  ],
                ),
                const SizedBox(width: RaSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entries[index].$1, style: RaText.label),
                  ),
                ),
                Text(entries[index].$2, style: RaText.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderRequestDetailsScreen extends StatelessWidget {
  const ProviderRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final driver = data['driverName'] as String? ?? 'Driver';
    final phone = data['driverPhone'] as String? ?? '';
    final status = (data['status'] as String? ?? 'unknown').replaceAll(
      '_',
      ' ',
    );
    final rawStatus = data['status'] as String? ?? 'unknown';
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final createdLabel = created == null
        ? 'Time unavailable'
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final registration = data['registration'] as String? ?? 'Not provided';
    final vehiclePhotos =
        (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Case Details')),
      body: ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          Row(
            children: [
              StatusPill(
                label: status.toUpperCase(),
                tone: rawStatus == 'completed'
                    ? RaTone.success
                    : rawStatus == 'cancelled'
                    ? RaTone.danger
                    : RaTone.info,
              ),
              const Spacer(),
              Text('CASE $requestId', style: RaText.eyebrow),
            ],
          ),
          const SizedBox(height: RaSpace.xs),
          Text(createdLabel, style: RaText.caption),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Customer Information'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      ProfileInitials(name: driver, radius: 24),
                      const SizedBox(width: RaSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver, style: RaText.title),
                            Text(
                              phone.isEmpty ? 'Phone not provided' : phone,
                              style: RaText.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: phone.isEmpty
                            ? null
                            : () => showCallPrompt(
                                context,
                                name: driver,
                                number: phone,
                              ),
                        icon: const Icon(Icons.call_outlined),
                        tooltip: 'Call customer',
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => push(
                        context,
                        CustomerContactScreen(
                          requestId: requestId,
                          requestData: data,
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact Customer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Vehicle Details'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  SummaryRow(
                    'Type',
                    data['vehicleType'] as String? ?? 'Not provided',
                  ),
                  SummaryRow(
                    'Model',
                    data['modelYear'] as String? ?? 'Not provided',
                  ),
                  SummaryRow('Registration', registration),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Incident Details'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryRow(
                    'Breakdown Type',
                    data['issue'] as String? ?? 'Roadside assistance',
                  ),
                  SummaryRow(
                    'Location',
                    data['locationLabel'] as String? ?? 'Pinned location',
                  ),
                  SummaryRow(
                    'Customer Notes',
                    data['description'] as String? ?? 'No description',
                  ),
                  if ((data['notes'] as String? ?? '').trim().isNotEmpty)
                    SummaryRow('Additional Notes', data['notes'] as String),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    height: 185,
                    child: MapMock(position: LatLng(latitude, longitude)),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () => openMapNavigation(
                      context,
                      latitude: latitude,
                      longitude: longitude,
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Open GPS Navigation'),
                  ),
                  if (vehiclePhotos.isNotEmpty) ...[
                    const SizedBox(height: RaSpace.md),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: vehiclePhotos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: RaSpace.sm),
                        itemBuilder: (context, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(RaRadius.sm),
                          child: Image.memory(
                            base64Decode(vehiclePhotos[index]),
                            width: 125,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: RaSpace.xxl),
                  SummaryRow(
                    'Service Charge',
                    'Rs. ${data['serviceFee'] ?? 0}',
                  ),
                  SummaryRow(
                    'Travel / Distance Charge',
                    'Rs. ${data['dispatchFee'] ?? 0}',
                  ),
                  SummaryRow('Extra Charge', 'Rs. ${data['extraFee'] ?? 0}'),
                  if ((data['providerDistanceKm'] as num?) != null)
                    SummaryRow(
                      'Provider Distance',
                      '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
                    ),
                  if ((data['quoteNotes'] as String? ?? '').isNotEmpty)
                    SummaryRow('Quote Notes', data['quoteNotes'] as String),
                  SummaryRow(
                    data['finalCost'] == null ? 'Quoted Total' : 'Final Total',
                    'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    strong: true,
                  ),
                  if (data['driverRating'] != null)
                    SummaryRow(
                      'Driver Rating',
                      '${data['driverRating']} / 5 stars',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Assigned Provider'),
          const SizedBox(height: RaSpace.sm),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: signedIn ? AuthService().watchCurrentProfile() : null,
            builder: (context, snapshot) {
              final profile = snapshot.data?.data();
              final providerName =
                  profile?['displayName'] as String? ?? 'Service Provider';
              final services =
                  (profile?['services'] as List<dynamic>? ?? const [])
                      .whereType<String>()
                      .join(', ');
              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: ProfileInitials(name: providerName, radius: 22),
                  title: Text(providerName, style: RaText.title),
                  subtitle: Text(
                    services.isEmpty ? 'RoadAssist Provider' : services,
                    style: RaText.caption,
                    maxLines: 2,
                  ),
                  trailing: const StatusPill(
                    label: 'Assigned',
                    tone: RaTone.info,
                    dot: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Vehicle History'),
          const SizedBox(height: RaSpace.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: signedIn ? RequestService().watchProviderRequests() : null,
            builder: (context, snapshot) {
              final previous =
                  snapshot.data?.docs
                      .where((request) {
                        final requestData = request.data();
                        return request.id != requestId &&
                            registration != 'Not provided' &&
                            requestData['registration'] == registration &&
                            requestData['status'] == 'completed';
                      })
                      .take(3)
                      .toList() ??
                  const [];
              if (previous.isEmpty) {
                return const InlineMessage(
                  icon: Icons.history_outlined,
                  text:
                      'No previous completed services for this vehicle with your account.',
                );
              }
              return Card(
                color: Colors.white,
                child: Column(
                  children: previous.map((request) {
                    final history = request.data();
                    final completed = (history['completedAt'] as Timestamp?)
                        ?.toDate();
                    final date = completed == null
                        ? 'Completed service'
                        : '${completed.day.toString().padLeft(2, '0')}/${completed.month.toString().padLeft(2, '0')}/${completed.year}';
                    return ListTile(
                      leading: const IconBadge(
                        Icons.build_circle_outlined,
                        size: 36,
                      ),
                      title: Text(
                        history['issue'] as String? ?? 'Roadside assistance',
                        style: RaText.title,
                      ),
                      subtitle: Text(date, style: RaText.caption),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => push(
                        context,
                        ProviderRequestDetailsScreen(
                          requestId: request.id,
                          data: history,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CustomerContactScreen extends StatelessWidget {
  const CustomerContactScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  final String requestId;
  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    final driver = requestData['driverName'] as String? ?? 'Driver';
    final phone = requestData['driverPhone'] as String? ?? '';
    final status = (requestData['status'] as String? ?? 'unknown').replaceAll(
      '_',
      ' ',
    );
    final vehicle = [
      requestData['modelYear'],
      requestData['registration'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' - ');
    final issue = requestData['issue'] as String? ?? 'Roadside assistance';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Customer'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: RaSpace.md),
            child: StatusPill(label: 'Live Session', tone: RaTone.success),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Row(
                        children: [
                          ProfileInitials(name: driver, radius: 28),
                          const SizedBox(width: RaSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver, style: RaText.headline),
                                const SizedBox(height: 2),
                                Text(
                                  phone.isEmpty ? 'Phone not provided' : phone,
                                  style: RaText.bodyMuted,
                                ),
                                const SizedBox(height: RaSpace.xs),
                                const StatusPill(
                                  label: 'RoadAssist Driver',
                                  tone: RaTone.info,
                                  dot: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  const SectionTitle('Case Information'),
                  const SizedBox(height: RaSpace.sm),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.tag_outlined,
                            label: 'Case ID',
                            value: requestId,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.sync_outlined,
                            label: 'Status',
                            value: status,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.directions_car_outlined,
                            label: 'Vehicle',
                            value: vehicle.isEmpty ? 'Not provided' : vehicle,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.warning_amber_outlined,
                            label: 'Issue Reported',
                            value: issue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  const InlineMessage(
                    icon: Icons.shield_outlined,
                    text:
                        'Customer contact details are available only for this assigned assistance request.',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(RaSpace.xl),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: raLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: phone.isEmpty
                        ? null
                        : () => showCallPrompt(
                            context,
                            name: driver,
                            number: phone,
                          ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call Customer'),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () => push(
                      context,
                      ChatScreen(
                        requestId: requestId,
                        peerName: driver,
                        peerPhone: phone,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Send Message'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: const Text('Back to Case Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderJobCard extends StatelessWidget {
  const ProviderJobCard({
    super.key,
    required this.driver,
    required this.vehicle,
    required this.service,
    required this.date,
    required this.location,
    required this.cost,
    required this.completed,
    required this.onViewDetails,
  });

  final String driver;
  final String vehicle;
  final String service;
  final String date;
  final String location;
  final String cost;
  final bool completed;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileInitials(name: driver, radius: 20),
              const SizedBox(width: RaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver, style: RaText.title),
                    Text(vehicle, style: RaText.caption),
                  ],
                ),
              ),
              Text(cost, style: RaText.numeric.copyWith(fontSize: 16)),
            ],
          ),
          const Divider(height: RaSpace.xxl),
          SummaryRow('Service', service),
          SummaryRow('Date & Time', date),
          SummaryRow('Location', location),
          const SizedBox(height: RaSpace.sm),
          Row(
            children: [
              StatusPill(
                label: completed ? 'Completed' : 'Cancelled',
                tone: completed ? RaTone.success : RaTone.danger,
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewDetails,
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ProviderServiceTile extends StatelessWidget {
  const ProviderServiceTile({
    super.key,
    required this.icon,
    required this.title,
  });
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, size: 38),
          const SizedBox(height: RaSpace.sm),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                style: RaText.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      vertical: RaSpace.xxxl,
      horizontal: RaSpace.xl,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(RaRadius.md),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      children: [
        IconBadge(icon, size: 52, color: raMuted),
        const SizedBox(height: RaSpace.md),
        Text(title, style: RaText.title, textAlign: TextAlign.center),
        const SizedBox(height: RaSpace.xs),
        Text(message, textAlign: TextAlign.center, style: RaText.bodyMuted),
      ],
    ),
  );
}

// ============================================================
// SHARED — BRAND, LAYOUT & INPUT PRIMITIVES
// ============================================================

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, this.elevated = false});
  final double size;
  final bool elevated;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: raBlue,
      borderRadius: BorderRadius.circular(size * .26),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    ),
    child: Icon(Icons.shield_outlined, color: Colors.white, size: size * .55),
  );
}

class Dot extends StatelessWidget {
  const Dot({super.key, this.active = false, this.onDark = false});
  final bool active;
  final bool onDark;
  @override
  Widget build(BuildContext context) => Container(
    width: active ? 8 : 6,
    height: active ? 8 : 6,
    margin: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: active
          ? (onDark ? Colors.white : raBlue)
          : (onDark ? Colors.white24 : raLine),
      shape: BoxShape.circle,
    ),
  );
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      RaSpace.lg,
      RaSpace.md,
      RaSpace.lg,
      RaSpace.lg,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF397DBD), Color(0xFF4A90CF)],
      ),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(RaRadius.lg),
      ),
    ),
    child: child,
  );
}

class AssetSlot extends StatelessWidget {
  const AssetSlot({
    super.key,
    required this.height,
    required this.label,
    required this.icon,
    this.assetPath,
  });
  final double height;
  final String label;
  final IconData icon;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    color: const Color(0xFFDCE8F2),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: ScenicPainter()),
        if (assetPath != null)
          Image.asset(
            assetPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (assetPath == null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(RaSpace.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(RaRadius.sm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: raBlue, size: 34),
                  const SizedBox(height: RaSpace.xs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: raNavy,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class ScenicPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFB7D9EC));
    final hill = Path()
      ..moveTo(0, s.height * .58)
      ..quadraticBezierTo(
        s.width * .28,
        s.height * .2,
        s.width * .54,
        s.height * .58,
      )
      ..quadraticBezierTo(s.width * .78, s.height * .32, s.width, s.height * .6)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(hill, Paint()..color = const Color(0xFF568D72));
    final road = Path()
      ..moveTo(s.width * .42, s.height)
      ..quadraticBezierTo(
        s.width * .52,
        s.height * .66,
        s.width * .62,
        s.height * .49,
      )
      ..lineTo(s.width * .7, s.height * .51)
      ..quadraticBezierTo(s.width * .58, s.height * .7, s.width * .63, s.height)
      ..close();
    c.drawPath(road, Paint()..color = const Color(0xFF485467));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FeatureTile extends StatelessWidget {
  const FeatureTile(this.icon, this.title, this.body, {super.key});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: RaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RaText.title),
                const SizedBox(height: 1),
                Text(body, style: RaText.caption),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RoleOptionCard extends StatelessWidget {
  const RoleOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon, size: 52, iconSize: 26),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: RaText.eyebrow.copyWith(
                        color: raBlue,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(title, style: RaText.title.copyWith(fontSize: 17)),
                    const SizedBox(height: RaSpace.xs),
                    Text(description, style: RaText.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.lg),
          const Divider(height: 1),
          const SizedBox(height: RaSpace.md),
          FilledButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RaSpace.sm),
    child: Text(text, style: RaText.eyebrow),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: RaText.headline)),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: raBlue,
            ),
          ),
        ),
    ],
  );
}

class StepEyebrow extends StatelessWidget {
  const StepEyebrow({super.key, required this.step, required this.of});
  final int step;
  final int of;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= of; i++) ...[
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? raBlue : raLine,
              borderRadius: BorderRadius.circular(RaRadius.pill),
            ),
          ),
        ),
        if (i != of) const SizedBox(width: RaSpace.xs),
      ],
    ],
  );
}

class ServicePreview extends StatelessWidget {
  const ServicePreview({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.assetPath,
  });
  final String title, detail;
  final IconData icon;
  final String assetPath;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            child: Image.asset(
              assetPath,
              height: 104,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 104,
                color: raPale,
                child: Icon(icon, color: raBlue, size: 36),
              ),
            ),
          ),
          const SizedBox(height: RaSpace.sm),
          Text(title, style: RaText.label),
          const SizedBox(height: 2),
          Text(detail, style: RaText.caption),
        ],
      ),
    ),
  );
}

class ContactTile extends StatelessWidget {
  const ContactTile(this.title, this.number, {super.key, required this.onTap});
  final String title, number;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: RaSpace.md,
      vertical: 2,
    ),
    leading: const IconBadge(
      Icons.emergency_outlined,
      background: raDangerPale,
      color: raDanger,
      size: 38,
    ),
    title: Text(title, style: RaText.title),
    subtitle: Text(number, style: RaText.caption),
    trailing: IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.call, size: 19),
    ),
  );
}

class SafetyBox extends StatelessWidget {
  const SafetyBox({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RaSpace.md),
    decoration: BoxDecoration(
      color: raGoldPale,
      borderRadius: BorderRadius.circular(RaRadius.sm),
      border: Border.all(color: raGold.withValues(alpha: 0.35)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: raGold),
        SizedBox(width: RaSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAFETY FIRST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A5600),
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                'Move your vehicle to the shoulder and turn on hazard lights if possible.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A5600),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      RaSpace.xl,
      RaSpace.sm,
      RaSpace.xl,
      RaSpace.xl,
    ),
    decoration: const BoxDecoration(
      color: raCard,
      border: Border(top: BorderSide(color: raLine)),
    ),
    child: FilledButton(onPressed: enabled ? onTap : null, child: Text(label)),
  );
}

class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.icon, this.title, {super.key});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconBadge(icon, size: 30, iconSize: 16),
      const SizedBox(width: RaSpace.sm),
      Text(title, style: RaText.title),
    ],
  );
}

// ============================================================
// SHARED — MAP
// ============================================================

class MapMock extends StatelessWidget {
  const MapMock({
    super.key,
    this.position,
    this.providerPosition,
    this.providerPositions = const [],
    this.selectedProviderPosition,
    this.onPositionSelected,
    this.showProviders = false,
    this.showRoute = false,
    this.routePoints,
  });

  final LatLng? position;
  final LatLng? providerPosition;
  final List<LatLng> providerPositions;
  final LatLng? selectedProviderPosition;
  final ValueChanged<LatLng>? onPositionSelected;
  final bool showProviders;
  final bool showRoute;
  final List<LatLng>? routePoints;

  static const breakdownPoint = LatLng(6.9034, 79.8525);
  static const providerPoint = LatLng(6.9147, 79.8601);

  @override
  Widget build(BuildContext context) {
    final selectedPoint = position ?? breakdownPoint;
    final activeProviderPoint = providerPosition ?? providerPoint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RaRadius.sm),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: selectedPoint,
          initialZoom: 14.5,
          onTap: onPositionSelected == null
              ? null
              : (_, point) => onPositionSelected!(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.roadassist.app',
          ),
          if (showRoute)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints == null || routePoints!.isEmpty
                      ? [activeProviderPoint, selectedPoint]
                      : routePoints!,
                  color: raBlue,
                  strokeWidth: 5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: selectedPoint,
                width: 54,
                height: 54,
                alignment: Alignment.topCenter,
                child: const _MapPin(
                  icon: Icons.directions_car,
                  color: raDanger,
                  label: 'Breakdown location',
                ),
              ),
              for (final point in providerPositions)
                Marker(
                  point: point,
                  width: 46,
                  height: 46,
                  alignment: Alignment.topCenter,
                  child: _MapPin(
                    icon: Icons.build,
                    color: point == selectedProviderPosition ? raGold : raBlue,
                    label: point == selectedProviderPosition
                        ? 'Selected service provider'
                        : 'Available service provider',
                  ),
                ),
              if ((showProviders || showRoute) && providerPositions.isEmpty)
                Marker(
                  point: activeProviderPoint,
                  width: 54,
                  height: 54,
                  alignment: Alignment.topCenter,
                  child: const _MapPin(
                    icon: Icons.build,
                    color: raBlue,
                    label: 'Service provider',
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
  );
}

// ============================================================
// SHARED — INFO / IDENTITY
// ============================================================

class InfoStrip extends StatelessWidget {
  const InfoStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RaSpace.md,
        vertical: 4,
      ),
      leading: IconBadge(icon),
      title: Text(title, style: RaText.title),
      subtitle: Text(value, style: RaText.caption),
    ),
  );
}

class ProviderTile extends StatelessWidget {
  const ProviderTile({
    super.key,
    required this.name,
    required this.company,
    required this.distance,
    required this.eta,
    required this.rating,
    this.assetPath,
    required this.selected,
    required this.onTap,
  });
  final String name, company, distance, eta, rating;
  final String? assetPath;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: selected
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF213A4B)
              : raPale)
        : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RaRadius.md),
      side: BorderSide(
        color: selected ? raBlue : raLine,
        width: selected ? 1.6 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(RaRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RaSpace.md),
        child: Row(
          children: [
            assetPath == null
                ? ProfileInitials(name: name)
                : AssetAvatar(label: 'Provider', assetPath: assetPath),
            const SizedBox(width: RaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RaText.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    company,
                    style: RaText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: RaSpace.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_filled,
                        size: 13,
                        color: raBlue,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '$distance · ETA $eta',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: raBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: raGold),
                    const SizedBox(width: 2),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: raGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RaSpace.md),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? raBlue : raFaint,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileInitials extends StatelessWidget {
  const ProfileInitials({
    super.key,
    required this.name,
    this.radius = 28,
    this.foregroundColor = raBlue,
    this.background,
  });

  final String name;
  final double radius;
  final Color foregroundColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((word) => word[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          background ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF263D4C)
              : raPale),
      child: Text(
        initials,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: radius * .6,
        ),
      ),
    );
  }
}

class AssetAvatar extends StatelessWidget {
  const AssetAvatar({
    super.key,
    required this.label,
    this.assetPath,
    this.radius = 28,
  });
  final String label;
  final String? assetPath;
  final double radius;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: CircleAvatar(
      radius: radius,
      backgroundColor: raPale,
      backgroundImage: assetPath == null ? null : AssetImage(assetPath!),
      child: assetPath == null
          ? const Icon(Icons.person, color: raBlue, size: 30)
          : null,
    ),
  );
}

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: strong ? RaText.title : RaText.bodyMuted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: strong ? raBlue : raInk,
              fontWeight: FontWeight.w800,
              fontSize: strong ? 17 : 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDF4),
      borderRadius: BorderRadius.circular(RaRadius.sm),
    ),
    child: Row(
      children: List.generate(3, (index) {
        const labels = ['All', 'Completed', 'Cancelled'];
        final active = selected == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
            child: Material(
              color: active ? raNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(RaRadius.sm - 2),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(RaRadius.sm - 2),
                child: Center(
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : raInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class HistoryCard extends StatelessWidget {
  const HistoryCard(
    this.title,
    this.provider,
    this.vehicle,
    this.cost,
    this.completed, {
    super.key,
  });
  final String title, provider, vehicle, cost;
  final bool completed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.car_repair, size: 34),
              const SizedBox(width: RaSpace.sm),
              Expanded(child: Text(title, style: RaText.title)),
              StatusPill(
                label: completed ? 'Completed' : 'Cancelled',
                tone: completed ? RaTone.success : RaTone.danger,
              ),
            ],
          ),
          const Divider(height: RaSpace.xxl),
          SummaryRow('Provider', provider),
          SummaryRow('Vehicle', vehicle),
          const Divider(),
          SummaryRow('Total Cost', cost, strong: true),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () =>
                  push(context, const DriverRequestDetailsScreen()),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// SHARED — DESIGN SYSTEM PRIMITIVES
// (icon containers + status pills used across every screen)
// ============================================================

enum RaTone { success, danger, warning, info, neutral }

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = raBlue,
    this.background,
    this.size = 40,
    this.iconSize,
  });
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color:
          background ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF263D4C)
              : raPale),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = RaTone.info,
    this.dot = true,
  });
  final String label;
  final RaTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      RaTone.success => (raSuccessPale, raSuccess),
      RaTone.danger => (raDangerPale, raDanger),
      RaTone.warning => (raGoldPale, const Color(0xFFA5670C)),
      RaTone.info => (raPale, raBlue),
      RaTone.neutral => (const Color(0xFFF0F2F6), raMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
