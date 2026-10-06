import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderVerificationService {
  final db = FirebaseFirestore.instance;
  Future<void> submit(Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your email before submitting your application.');
    }
    await user.getIdToken(true);
    final ref = db.collection('providerApplications').doc(user.uid);
    await db.runTransaction((tx) async {
      final previous = (await tx.get(ref)).data();
      tx.set(ref, {
        ...details,
        'revision': ((previous?['revision'] as num?)?.toInt() ?? 0) + 1,
        'submittedAt': FieldValue.serverTimestamp(),
        'termsAccepted': true,
        'consentVersion': 1,
      });
    });
  }
}
