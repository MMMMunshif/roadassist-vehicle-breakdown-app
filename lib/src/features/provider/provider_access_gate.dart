part of '../../screens.dart';

// Every provider entry route passes through this gate. Rules enforce it too.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const WelcomeScreen();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerApplications')
          .doc(user.uid)
          .snapshots(),
      builder: (context, application) =>
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('accountModeration')
                .doc(user.uid)
                .snapshots(),
            builder: (context, moderation) {
              if (application.hasError || moderation.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Unable to check verification. Reconnect and try again.',
                    ),
                  ),
                );
              }
              if (!application.hasData || !moderation.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final a = application.data?.data();
              final m = moderation.data?.data();
              final approved =
                  user.emailVerified &&
                  a != null &&
                  a['professionalDetails'] is Map &&
                  m?['verification'] == 'verified' &&
                  m?['status'] == 'active' &&
                  m?['verificationRevision'] == a['revision'] &&
                  ((m?['validUntil'] as Timestamp?)?.toDate().isAfter(
                        DateTime.now(),
                      ) ??
                      false);
              if (approved) return const ApprovedProviderShell();
              return ProviderVerificationScreen(application: a, moderation: m);
            },
          ),
    );
  }
}
