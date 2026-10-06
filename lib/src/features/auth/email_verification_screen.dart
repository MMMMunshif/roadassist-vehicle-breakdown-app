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
