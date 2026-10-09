part of '../../screens.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final formKey = GlobalKey<FormState>();

  final email = TextEditingController();
  final password = TextEditingController();

  bool checking = true;
  bool allowed = false;
  bool busy = false;
  bool obscurePassword = true;

  String? error;

  @override
  void initState() {
    super.initState();

    unawaited(_checkAccess());
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();

    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      await AdminService().requireAdmin();

      if (!mounted) {
        return;
      }

      setState(() {
        allowed = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        allowed = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
        });
      }
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (busy || !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      await AdminService().requireAdmin();

      if (!mounted) {
        return;
      }

      password.clear();

      setState(() {
        allowed = true;
      });
    } on FirebaseAuthException catch (exception) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      final message = switch (exception.code) {
        'invalid-credential' => 'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many sign-in attempts. Try again later.',
        'network-request-failed' =>
          'Network unavailable. Check your connection.',
        _ => 'Sign-in failed or this account has no verified admin permission.',
      };

      setState(() {
        error = message;
      });
    } catch (_) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      setState(() {
        error =
            'Sign-in failed or this account has no verified admin permission.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of admin?'),
        content: const Text(
          'You will need to sign in again to manage RoadAssist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService().signOut();

    if (!mounted) {
      return;
    }

    setState(() {
      allowed = false;
      error = null;
      password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const _RaAdminAccessLoading();
    }

    if (allowed) {
      return AdminDashboardScreen(onSignOut: _signOut);
    }

    return _RaAdminLoginScreen(
      formKey: formKey,
      email: email,
      password: password,
      busy: busy,
      error: error,
      obscurePassword: obscurePassword,
      onTogglePassword: () {
        setState(() {
          obscurePassword = !obscurePassword;
        });
      },
      onLogin: _login,
    );
  }
}

class _RaAdminAccessLoading extends StatelessWidget {
  const _RaAdminAccessLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaAdminScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF0D2237)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: colors.primary,
                        size: 35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Checking admin access',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Confirming the signed-in account and its current RoadAssist administration permissions.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(minHeight: 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RaAdminLoginScreen extends StatelessWidget {
  const _RaAdminLoginScreen({
    required this.formKey,
    required this.email,
    required this.password,
    required this.busy,
    required this.error,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController email;
  final TextEditingController password;

  final bool busy;
  final String? error;
  final bool obscurePassword;

  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RaAdminScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: AutofillGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _WelcomeThemeToggle(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          BrandMark(size: 46),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RoadAssist',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.4,
                                  ),
                                ),
                                Text(
                                  'PRIVATE ADMINISTRATION',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .75,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: theme.brightness == Brightness.dark
                                ? const [Color(0xFF0A497F), Color(0xFF075A68)]
                                : const [Color(0xFF075BA8), Color(0xFF087D78)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 51,
                              height: 51,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Admin workspace',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Restricted access for verified RoadAssist administrators. Permissions are granted separately by the project owner.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF0D2237)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: .45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use an existing verified account with active admin permission.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 17),
                            TextFormField(
                              controller: email,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Admin email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: validateEmailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: password,
                              enabled: !busy,
                              obscureText: obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: onTogglePassword,
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }

                                return null;
                              },
                              onFieldSubmitted: (_) {
                                if (!busy) {
                                  onLogin();
                                }
                              },
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              _RaAdminLoginNotice(text: error!),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: busy ? null : onLogin,
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                busy
                                    ? 'Checking access...'
                                    : 'Sign In to Admin',
                              ),
                            ),
                            if (busy) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'There is no public admin registration.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
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
          ),
        ),
      ),
    );
  }
}

class _RaAdminLoginNotice extends StatelessWidget {
  const _RaAdminLoginNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: .17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
