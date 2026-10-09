part of '../../screens.dart';

/// Every provider entry route passes through this gate.
/// Firestore/security rules remain the authority.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key});

  bool _isApproved({
    required User user,
    required Map<String, dynamic>? application,
    required Map<String, dynamic>? moderation,
  }) {
    final validUntil = (moderation?['validUntil'] as Timestamp?)?.toDate();

    final applicationRevision = application?['revision'];

    final verificationRevision = moderation?['verificationRevision'];

    return user.emailVerified &&
        application != null &&
        application['professionalDetails'] is Map &&
        application['applicationStatus'] != 'withdrawn' &&
        moderation?['verification'] == 'verified' &&
        moderation?['status'] == 'active' &&
        verificationRevision == applicationRevision &&
        validUntil != null &&
        validUntil.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const WelcomeScreen();
    }

    if (enforceEmailVerification && !user.emailVerified) {
      return const EmailVerificationScreen(role: 'provider');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerApplications')
          .doc(user.uid)
          .snapshots(),
      builder: (context, applicationSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('accountModeration')
              .doc(user.uid)
              .snapshots(),
          builder: (context, moderationSnapshot) {
            if (applicationSnapshot.hasError || moderationSnapshot.hasError) {
              return const _ProviderGateError();
            }

            if (!applicationSnapshot.hasData || !moderationSnapshot.hasData) {
              return const _ProviderGateLoading();
            }

            final application = applicationSnapshot.data?.data();

            final moderation = moderationSnapshot.data?.data();

            final approved = _isApproved(
              user: user,
              application: application,
              moderation: moderation,
            );

            if (approved) {
              return const ApprovedProviderShell();
            }

            return ProviderVerificationScreen(
              application: application,
              moderation: moderation,
            );
          },
        );
      },
    );
  }
}

class _ProviderGateLoading extends StatelessWidget {
  const _ProviderGateLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final dark = theme.brightness == Brightness.dark;

    return RaProviderScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0D2237) : colors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .085),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: colors.primary,
                        size: 35,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Checking provider access',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Confirming your account, provider application and verification status.',
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

                    const SizedBox(height: 12),

                    Text(
                      'ROADASSIST PROVIDER',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderGateError extends StatelessWidget {
  const _ProviderGateError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return RaProviderScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF0D2237)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .48),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        color: colors.error,
                        size: 32,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Unable to verify provider access',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.35,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'RoadAssist could not read your current provider verification status. Check your connection and open the provider portal again.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService().signOut();

                          if (!context.mounted) {
                            return;
                          }

                          replace(context, const WelcomeScreen());
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                      ),
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
