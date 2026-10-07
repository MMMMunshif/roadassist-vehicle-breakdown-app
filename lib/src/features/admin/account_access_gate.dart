part of '../../screens.dart';

class AccountAccessGate extends StatelessWidget {
  const AccountAccessGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) {
        final user = auth.data;

        if (user == null) {
          return child;
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('accountModeration')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return child;
            }

            if (!snapshot.hasData) {
              return const _AccountAccessCheckingScreen();
            }

            final moderation = snapshot.data?.data();

            final suspended =
                moderation?['status'] == 'suspended';

            final rejected =
                moderation?['verification'] == 'rejected';

            if (!suspended && !rejected) {
              return child;
            }

            return _AccountAccessBlockedScreen(
              reason:
                  moderation?['reason'] as String? ??
                      'Contact project support for more information.',
              rejected: rejected,
            );
          },
        );
      },
    );
  }
}

class _AccountAccessCheckingScreen extends StatelessWidget {
  const _AccountAccessCheckingScreen();

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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 34,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: RaSpace.lg),
                Text(
                  'Checking account access',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: RaSpace.sm),
                Text(
                  'Confirming your RoadAssist account status…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: RaSpace.xl),
                const SizedBox(
                  width: 110,
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

class _AccountAccessBlockedScreen extends StatelessWidget {
  const _AccountAccessBlockedScreen({
    required this.reason,
    required this.rejected,
  });

  final String reason;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(RaSpace.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(RaSpace.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: .50),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      rejected
                          ? Icons.gpp_bad_outlined
                          : Icons.lock_outline_rounded,
                      size: 38,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  Text(
                    rejected
                        ? 'Account verification rejected'
                        : 'App access suspended',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(RaSpace.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest
                          .withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.support_agent_outlined,
                          size: 20,
                        ),
                        SizedBox(width: RaSpace.sm),
                        Expanded(
                          child: Text(
                            'Contact RoadAssist project support if you need to request an account review.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService().signOut();
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
    );
  }
}