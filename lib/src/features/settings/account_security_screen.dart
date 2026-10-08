part of '../../screens.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({
    super.key,
  });

  @override
  State<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState
    extends State<AccountSecurityScreen> {
  bool deleting = false;
  bool sendingReset = false;

  Future<void> sendReset(
    String email,
  ) async {
    if (sendingReset) {
      return;
    }

    setState(() {
      sendingReset = true;
    });

    try {
      await AuthService().sendPasswordResetEmail(
        email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this account is available, a password-reset link will arrive shortly. Check Spam too.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send reset email: $error',
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
    final passwordController =
        TextEditingController();

    final confirmationController =
        TextEditingController();

    var obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final colors =
                Theme.of(context).colorScheme;

            final valid =
                passwordController.text.isNotEmpty &&
                confirmationController.text.trim() ==
                    'DELETE';

            return AlertDialog(
              icon: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.error.withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: colors.error,
                  size: 29,
                ),
              ),
              title: const Text(
                'Delete account permanently?',
              ),
              content: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your profile and saved device information will be removed. Completed service, payment, complaint or security records may remain where required.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 8.8,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          obscurePassword,
                      onChanged: (_) {
                        setDialogState(
                          () {},
                        );
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'Current password',
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline_rounded,
                        ),
                        suffixIcon:
                            IconButton(
                          tooltip:
                              obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                          onPressed: () {
                            setDialogState(
                              () {
                                obscurePassword =
                                    !obscurePassword;
                              },
                            );
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      controller:
                          confirmationController,
                      textCapitalization:
                          TextCapitalization
                              .characters,
                      onChanged: (_) {
                        setDialogState(
                          () {},
                        );
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Type DELETE to confirm',
                        prefixIcon: Icon(
                          Icons
                              .warning_amber_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      'This action cannot be automatically undone.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 7.7,
                        color: colors.error,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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
                    'Keep Account',
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
                  onPressed: valid
                      ? () {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        }
                      : null,
                  child: const Text(
                    'Delete Permanently',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final password =
        passwordController.text;

    passwordController.dispose();
    confirmationController.dispose();

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      deleting = true;
    });

    try {
      await AuthService()
          .deleteCurrentAccount(
        password: password,
      );

      if (!mounted) {
        return;
      }

      replace(
        context,
        const WelcomeScreen(),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          switch (error.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'The password is incorrect. Your account was not deleted.',
        'too-many-requests' =>
          'Too many attempts. Please try again later.',
        'requires-recent-login' =>
          'Please sign out, sign in again and retry.',
        _ =>
          error.message ??
              'Unable to delete the account.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: raDanger,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete account: $error',
          ),
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
    final theme =
        Theme.of(context);

    final user = firebaseReady
        ? FirebaseAuth.instance.currentUser
        : null;

    if (!signedIn || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Account & Security',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(18),
          child: EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message:
                'Sign in to manage your RoadAssist account security.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Account & Security',
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
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
          32,
        ),
        children: [
          const _RaSecurityHero(),
          const SizedBox(height: 23),
          const _RaSecurityHeading(
            title: 'Account',
            subtitle:
                'Your current sign-in identity and email verification status.',
          ),
          const SizedBox(height: 10),
          _RaSecurityAccountCard(
            email:
                user.email ??
                    'Email unavailable',
            verified:
                user.emailVerified,
          ),
          const SizedBox(height: 12),
          _RaSecuritySurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _RaSecurityMenuTile(
                  icon:
                      Icons.password_outlined,
                  title:
                      'Reset Password',
                  subtitle:
                      'Receive a secure password-reset email',
                  trailing: sendingReset
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  onTap: user.email == null ||
                          sendingReset
                      ? null
                      : () {
                          sendReset(
                            user.email!,
                          );
                        },
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                ),
                _RaSecurityMenuTile(
                  icon: Icons
                      .notifications_outlined,
                  title:
                      'Notification Settings',
                  subtitle:
                      'Background alerts and device permissions',
                  onTap: () {
                    push(
                      context,
                      const NotificationSettingsScreen(),
                    );
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                ),
                _RaSecurityMenuTile(
                  icon:
                      Icons.privacy_tip_outlined,
                  title:
                      'Privacy & Safety',
                  subtitle:
                      'Review privacy and account-safety information',
                  onTap: () {
                    push(
                      context,
                      const PrivacySafetyScreen(
                        isProvider: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _RaSecurityHeading(
            title: 'Danger zone',
            subtitle:
                'Permanent account actions cannot be automatically undone.',
            tone:
                Theme.of(context)
                    .colorScheme
                    .error,
          ),
          const SizedBox(height: 10),
          _RaSecurityDangerCard(
            deleting: deleting,
            onDelete: deleteAccount,
          ),
        ],
      ),
    );
  }
}

class _RaSecurityHero
    extends StatelessWidget {
  const _RaSecurityHero();

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0A497F),
                  Color(0xFF075A68),
                ]
              : const [
                  Color(0xFF075BA8),
                  Color(0xFF078C7E),
                ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Protect your account',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage password recovery, verification and account access.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 8.5,
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
}

class _RaSecurityHeading
    extends StatelessWidget {
  const _RaSecurityHeading({
    required this.title,
    required this.subtitle,
    this.tone,
  });

  final String title;
  final String subtitle;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: tone,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 8.3,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RaSecuritySurface
    extends StatelessWidget {
  const _RaSecuritySurface({
    required this.child,
    this.padding =
        const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.brightness ==
                Brightness.dark
            ? const Color(0xFF0D1D2B)
            : theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: child,
    );
  }
}

class _RaSecurityAccountCard
    extends StatelessWidget {
  const _RaSecurityAccountCard({
    required this.email,
    required this.verified,
  });

  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final tone =
        verified ? raSuccess : raGold;

    return _RaSecuritySurface(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  tone.withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              verified
                  ? Icons.verified_outlined
                  : Icons
                      .mark_email_unread_outlined,
              color: tone,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  verified
                      ? 'Email verified'
                      : enforceEmailVerification
                          ? 'Email verification required'
                          : 'Verification unavailable',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 7.8,
                    fontWeight:
                        FontWeight.w700,
                    color: tone,
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

class _RaSecurityMenuTile
    extends StatelessWidget {
  const _RaSecurityMenuTile({
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
    final colors =
        Theme.of(context).colorScheme;

    return ListTile(
      enabled: onTap != null,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 2,
      ),
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: colors.primary
              .withValues(alpha: .07),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: colors.primary,
        ),
      ),
      title: Text(
        title,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 9.6,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 7.5,
          color:
              colors.onSurfaceVariant,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
          ),
      onTap: onTap,
    );
  }
}

class _RaSecurityDangerCard
    extends StatelessWidget {
  const _RaSecurityDangerCard({
    required this.deleting,
    required this.onDelete,
  });

  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.error
            .withValues(alpha: .055),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.error
              .withValues(alpha: .20),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: colors.error
                      .withValues(
                    alpha: .08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons
                      .delete_forever_outlined,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete RoadAssist account',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w800,
                    color: colors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your active profile will be removed. Some completed service, payment, complaint or security records may still be retained where required.',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 8.2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  colors.error,
              side: BorderSide(
                color: colors.error
                    .withValues(
                  alpha: .45,
                ),
              ),
            ),
            onPressed:
                deleting ? null : onDelete,
            icon: deleting
                ? const SizedBox.square(
                    dimension: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .delete_forever_outlined,
                  ),
            label: Text(
              deleting
                  ? 'Deleting Account…'
                  : 'Delete Account Permanently',
            ),
          ),
        ],
      ),
    );
  }
}