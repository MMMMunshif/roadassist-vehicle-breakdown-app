part of '../../screens.dart';

class RoleEmailGate extends StatelessWidget {
  const RoleEmailGate({super.key, required this.role, required this.child});
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified)
      return EmailVerificationScreen(role: role);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AuthService().watchCurrentProfile(),
      builder: (context, profile) {
        if (profile.hasError) return EmailVerificationScreen(role: role);
        if (!profile.hasData) return const _AccountAccessCheckingScreen();
        if (!accountHasRole(profile.data?.data(), role))
          return EmailVerificationScreen(role: role);
        final required =
            (profile.data?.data()?['roleEmailRequired'] as List?) ?? const [];
        if (!required.contains(role)) return child;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('roleEmailVerifications')
              .doc(user.uid)
              .snapshots(),
          builder: (context, verification) {
            if (verification.hasError)
              return EmailVerificationScreen(role: role);
            if (!verification.hasData)
              return const _AccountAccessCheckingScreen();
            final record = verification.data?.data()?[role];
            return record is Map && record['email'] == user.email?.toLowerCase()
                ? child
                : EmailVerificationScreen(role: role);
          },
        );
      },
    );
  }
}
