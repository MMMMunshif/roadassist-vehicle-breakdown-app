part of '../../screens.dart';

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
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Push notifications'),
              subtitle: const Text('Background alerts and device permissions'),
              onTap: () => push(context, const NotificationSettingsScreen()),
            ),
          ),
          const SizedBox(height: RaSpace.md),
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
