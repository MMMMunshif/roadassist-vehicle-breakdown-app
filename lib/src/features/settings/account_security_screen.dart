part of '../../screens.dart';

class AccountSecurityScreen
    extends StatefulWidget {
  const AccountSecurityScreen({
    super.key,
  });

  @override
  State<AccountSecurityScreen>
      createState() =>
          _AccountSecurityScreenState();
}

class _AccountSecurityScreenState
    extends State<AccountSecurityScreen> {
  bool deleting = false;
  bool sendingReset = false;

  Future<void> sendReset(
    String email,
  ) async {
    if (sendingReset) return;

    setState(() {
      sendingReset = true;
    });

    try {
      await AuthService()
          .sendPasswordResetEmail(
        email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'If this account is available, a password-reset link will arrive shortly. Check Spam too.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send password reset: $error',
          ),
          backgroundColor: raDanger,
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

    final confirmed =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final theme =
                Theme.of(context);

            final colors =
                theme.colorScheme;

            final valid =
                passwordController
                    .text
                    .isNotEmpty &&
                confirmationController
                        .text
                        .trim() ==
                    'DELETE';

            return AlertDialog(
              icon: Container(
                width: 56,
                height: 56,
                decoration:
                    BoxDecoration(
                  color: colors.error
                      .withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Icon(
                  Icons
                      .delete_forever_outlined,
                  color: colors.error,
                  size: 29,
                ),
              ),
              title: const Text(
                'Delete account permanently?',
              ),
              content: SizedBox(
                width: 390,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      'Your profile and saved device tokens will be removed. Completed service records may still be retained where required for security and transaction history.',
                      style: GoogleFonts
                          .plusJakartaSans(
                        fontSize: 10.5,
                        height: 1.5,
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 17,
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

      if (!mounted) return;

      replace(
        context,
        const WelcomeScreen(),
      );
    } on FirebaseAuthException catch (
        error) {
      if (!mounted) return;

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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: raDanger,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final user = firebaseReady
        ? FirebaseAuth
            .instance.currentUser
        : null;

    if (!signedIn || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Account & Security',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
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
            letterSpacing: -.45,
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

          const SizedBox(height: 26),

          const _RaSecurityHeading(
            title: 'Account',
            subtitle:
                'Your sign-in identity and verification status.',
          ),

          const SizedBox(height: 11),

          _RaSecurityAccountCard(
            email: user.email ??
                'Email unavailable',
            verified:
                user.emailVerified,
          ),

          const SizedBox(height: 12),

          _RaSecurityMenuCard(
            children: [
              _RaSecurityMenuTile(
                icon:
                    Icons.password_outlined,
                title:
                    'Reset Password',
                subtitle:
                    'Receive a secure reset link by email',
                trailing: sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : null,
                onTap: user.email ==
                            null ||
                        sendingReset
                    ? null
                    : () {
                        sendReset(
                          user.email!,
                        );
                      },
              ),

              _RaSecurityMenuTile(
                icon: Icons
                    .notifications_outlined,
                title:
                    'Push Notifications',
                subtitle:
                    'Manage alerts for this device',
                onTap: () {
                  push(
                    context,
                    const NotificationSettingsScreen(),
                  );
                },
              ),

              _RaSecurityMenuTile(
                icon:
                    Icons.privacy_tip_outlined,
                title:
                    'Privacy & Safety',
                subtitle:
                    'Review data visibility and permissions',
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

          const SizedBox(height: 28),

          _RaSecurityHeading(
            title: 'Danger zone',
            subtitle:
                'Permanent account actions cannot be automatically undone.',
            danger: true,
          ),

          const SizedBox(height: 11),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.error
                  .withValues(alpha: .055),
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color: colors.error
                    .withValues(
                  alpha: .20,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                          alpha: .10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          13,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .delete_forever_outlined,
                        color:
                            colors.error,
                        size: 21,
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child: Text(
                        'Delete RoadAssist account',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color:
                              colors.error,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 11,
                ),

                Text(
                  'Your profile will be removed. Some completed service records may remain where required for transaction and security history.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 10,
                    height: 1.45,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: deleting
                        ? null
                        : deleteAccount,
                    style: OutlinedButton
                        .styleFrom(
                      foregroundColor:
                          colors.error,
                      side: BorderSide(
                        color: colors.error
                            .withValues(
                          alpha: .45,
                        ),
                      ),
                    ),
                    icon: deleting
                        ? const SizedBox
                            .square(
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
                    label: const Text(
                      'Delete Account Permanently',
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

class _RaSecurityHero
    extends StatelessWidget {
  const _RaSecurityHero();

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
                  Color(0xFF0B477D),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
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

          const SizedBox(width: 13),

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
                    letterSpacing: -.4,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Manage sign-in security, password recovery and device notifications.',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: Colors.white
                        .withValues(
                      alpha: .80,
                    ),
                    fontSize: 10,
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
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final bool danger;

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
            color: danger
                ? colors.error
                : colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style:
              GoogleFonts.plusJakartaSans(
            fontSize: 10,
            height: 1.4,
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark =
        theme.brightness == Brightness.dark;

    final tone =
        verified ? raSuccess : raGold;

    return Container(
      padding: const EdgeInsets.all(15),
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
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color:
                  tone.withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              verified
                  ? Icons.verified_rounded
                  : Icons
                      .mark_email_unread_outlined,
              color: tone,
            ),
          ),

          const SizedBox(width: 12),

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
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified
                      ? 'Email verified'
                      : enforceEmailVerification
                          ? 'Email verification required'
                          : 'Verification unavailable',
                  style: GoogleFonts
                      .plusJakartaSans(
                    color: tone,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w600,
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

class _RaSecurityMenuCard
    extends StatelessWidget {
  const _RaSecurityMenuCard({
    required this.children,
  });

  final List<_RaSecurityMenuTile>
      children;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0;
              index < children.length;
              index++) ...[
            children[index],
            if (index !=
                children.length - 1)
              Divider(
                height: 1,
                indent: 59,
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
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      onTap: onTap,
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: colors.primary
              .withValues(alpha: .08),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: colors.primary,
          size: 19,
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
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 8.8,
          color:
              colors.onSurfaceVariant,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color:
                colors.onSurfaceVariant,
          ),
    );
  }
}