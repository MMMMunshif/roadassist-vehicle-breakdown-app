part of '../../screens.dart';

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

    setState(() {
      checking = true;
    });

    try {
      final verified = await AuthService().refreshEmailVerification();

      if (!mounted) return;

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email is not verified yet. Open the verification link and try again.',
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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to check verification: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
        });
      }
    }
  }

  Future<void> resendVerification() async {
    if (sending) return;

    setState(() {
      sending = true;
    });

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
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  Future<void> useDifferentAccount() async {
    await AuthService().signOut();

    if (!mounted) return;

    replace(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email address';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              RaSpace.lg,
              RaSpace.xl,
              RaSpace.lg,
              RaSpace.xxxl,
            ),
            children: [
              const _AuthWordmark(),

              const SizedBox(height: RaSpace.xxl),

              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 46,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: RaSpace.xl),

              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: RaSpace.sm),

              Text(
                'We sent a verification link to',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                email,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: RaSpace.xl),

              Container(
                padding: const EdgeInsets.all(RaSpace.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .6),
                  ),
                ),
                child: Column(
                  children: [
                    const _VerificationStep(
                      number: '1',
                      title: 'Open your email',
                      message: 'Look for the RoadAssist verification email.',
                    ),
                    const SizedBox(height: RaSpace.md),
                    const _VerificationStep(
                      number: '2',
                      title: 'Open the verification link',
                      message:
                          'Complete verification in your browser or email app.',
                    ),
                    const SizedBox(height: RaSpace.md),
                    _VerificationStep(
                      number: '3',
                      title: 'Return to RoadAssist',
                      message: widget.role == 'provider'
                          ? 'After verification, continue to your provider account and verification workflow.'
                          : 'After verification, continue to your driver account.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: RaSpace.xl),

              FilledButton.icon(
                onPressed: checking ? null : checkVerification,
                icon: checking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(
                  checking
                      ? 'Checking Verification…'
                      : 'I Have Verified My Email',
                ),
              ),

              const SizedBox(height: RaSpace.sm),

              OutlinedButton.icon(
                onPressed: sending ? null : resendVerification,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forward_to_inbox_outlined),
                label: Text(sending ? 'Sending…' : 'Resend Verification Email'),
              ),

              const SizedBox(height: RaSpace.md),

              TextButton.icon(
                onPressed: checking || sending ? null : useDifferentAccount,
                icon: const Icon(Icons.switch_account_outlined),
                label: const Text('Use a Different Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.number,
    required this.title,
    required this.message,
  });

  final String number;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            number,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: RaSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
