part of '../../screens.dart';

// Every provider entry route passes through this gate.
// Firestore/security rules remain the authority.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const WelcomeScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerApplications')
          .doc(user.uid)
          .snapshots(),
      builder: (context, application) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('accountModeration')
              .doc(user.uid)
              .snapshots(),
          builder: (context, moderation) {
            if (application.hasError || moderation.hasError) {
              return const _ProviderGateError();
            }

            if (!application.hasData || !moderation.hasData) {
              return const _ProviderGateLoading();
            }

            final applicationData = application.data?.data();
            final moderationData = moderation.data?.data();

            final validUntil =
                (moderationData?['validUntil'] as Timestamp?)?.toDate();

            final approved =
                user.emailVerified &&
                applicationData != null &&
                applicationData['professionalDetails'] is Map &&
                moderationData?['verification'] == 'verified' &&
                moderationData?['status'] == 'active' &&
                moderationData?['verificationRevision'] ==
                    applicationData['revision'] &&
                (validUntil?.isAfter(DateTime.now()) ?? false);

            if (approved) {
              return const ApprovedProviderShell();
            }

            return ProviderVerificationScreen(
              application: applicationData,
              moderation: moderationData,
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 38,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                Text(
                  'Checking provider access',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: RaSpace.sm),
                Text(
                  'Confirming your account and verification status…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ],
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaSpace.xxl),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(RaSpace.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 34,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  const Text(
                    'Unable to verify provider access',
                    textAlign: TextAlign.center,
                    style: RaText.headline,
                  ),
                  const SizedBox(height: RaSpace.sm),
                  const Text(
                    'Check your internet connection and reopen the provider portal.',
                    textAlign: TextAlign.center,
                    style: RaText.bodyMuted,
                  ),
                  const SizedBox(height: RaSpace.lg),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();

                      if (context.mounted) {
                        replace(context, const WelcomeScreen());
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}