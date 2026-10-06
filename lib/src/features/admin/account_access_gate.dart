part of '../../screens.dart';

class AccountAccessGate extends StatelessWidget {
  const AccountAccessGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, auth) {
      final user = auth.data;
      if (user == null) return child;
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('accountModeration')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.data?.data()?['status'] != 'suspended' &&
              snapshot.data?.data()?['verification'] != 'rejected')
            return child;
          return Material(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline),
                    const Text('App access suspended', style: RaText.title),
                    Text(
                      snapshot.data?.data()?['reason'] as String? ??
                          'Contact project support.',
                    ),
                    const Text('Contact project support to request a review.'),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
