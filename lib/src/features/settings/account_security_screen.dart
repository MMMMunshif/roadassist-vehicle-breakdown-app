part of '../../screens.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool deleting = false;
  bool sendingReset = false;

  Future<void> sendReset(String email) async {
    if (sendingReset) return;

    setState(() {
      sendingReset = true;
    });

    try {
      await AuthService().sendPasswordResetEmail(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this account is available, a password-reset link will arrive shortly. Check Spam too.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sendingReset = false;
        });
      }
    }
  }

  Future<void> deleteAccount() async {
    final passwordController = TextEditingController();

    final confirmationController = TextEditingController();

    var obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            final colors = theme.colorScheme;

            final valid =
                passwordController.text.isNotEmpty &&
                confirmationController.text.trim() == 'DELETE';

            return AlertDialog(
              icon: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: colors.error,
                  size: 29,
                ),
              ),
              title: const Text('Delete account permanently?'),
              content: SizedBox(
                width: 390,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your profile and saved device tokens will be removed. Completed service records may still be retained where required for security and transaction history.',
                      style: theme.textTheme.bodyMedium,
                    ),

                    const SizedBox(height: RaSpace.lg),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    TextField(
                      controller: confirmationController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Type DELETE to confirm',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep Account'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: valid
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );

    final password = passwordController.text;

    passwordController.dispose();
    confirmationController.dispose();

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      deleting = true;
    });

    try {
      await AuthService().deleteCurrentAccount(password: password);

      if (!mounted) return;

      replace(context, const WelcomeScreen());
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'wrong-password' || 'invalid-credential' =>
          'The password is incorrect. Your account was not deleted.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'requires-recent-login' => 'Please sign out, sign in again and retry.',
        _ => error.message ?? 'Unable to delete the account.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: raDanger),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete account: $error'),
          backgroundColor: raDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (!signedIn || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account & Security')),
        body: const Padding(
          padding: EdgeInsets.all(RaSpace.lg),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in to manage your RoadAssist account security.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(title: const Text('Account & Security')),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RaSpace.lg,
          RaSpace.md,
          RaSpace.lg,
          RaSpace.xxxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(RaSpace.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, const Color(0xFF007D70)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(height: RaSpace.lg),
                Text(
                  'Protect your account',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Manage sign-in security, password recovery and notification permissions.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RaSpace.xl),

          Text(
            'Account',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: RaSpace.md),

          _SecurityAccountCard(
            email: user.email ?? 'Email unavailable',
            verified: user.emailVerified,
          ),

          const SizedBox(height: RaSpace.md),

          _SecurityMenuCard(
            children: [
              _SecurityMenuTile(
                icon: Icons.password_outlined,
                title: 'Reset Password',
                subtitle: 'Receive a secure password-reset email',
                trailing: sendingReset
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: user.email == null || sendingReset
                    ? null
                    : () => sendReset(user.email!),
              ),
              _SecurityMenuTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Background alerts and device permissions',
                onTap: () => push(context, const NotificationSettingsScreen()),
              ),
            ],
          ),

          const SizedBox(height: RaSpace.xxl),

          Text(
            'Danger zone',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Permanent account actions cannot be automatically undone.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: RaSpace.md),

          Container(
            padding: const EdgeInsets.all(RaSpace.lg),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.error.withValues(alpha: .25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete_forever_outlined, color: colors.error),
                    const SizedBox(width: RaSpace.sm),
                    Expanded(
                      child: Text(
                        'Delete RoadAssist account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: RaSpace.sm),

                Text(
                  'Your profile will be removed. Some completed service records may remain where required for transaction and security history.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),

                const SizedBox(height: RaSpace.md),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: deleting ? null : deleteAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: .55),
                      ),
                    ),
                    icon: deleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete Account Permanently'),
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

class _SecurityAccountCard extends StatelessWidget {
  const _SecurityAccountCard({required this.email, required this.verified});

  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final color = verified ? raSuccess : raGold;

    return Container(
      padding: const EdgeInsets.all(RaSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              verified
                  ? Icons.verified_outlined
                  : Icons.mark_email_unread_outlined,
              color: color,
            ),
          ),

          const SizedBox(width: RaSpace.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  verified
                      ? 'Email verified'
                      : enforceEmailVerification
                      ? 'Email verification required'
                      : 'Verification temporarily unavailable',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

class _SecurityMenuCard extends StatelessWidget {
  const _SecurityMenuCard({required this.children});

  final List<_SecurityMenuTile> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
          ],
        ],
      ),
    );
  }
}

class _SecurityMenuTile extends StatelessWidget {
  const _SecurityMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RaSpace.md,
        vertical: 5,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colors.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
