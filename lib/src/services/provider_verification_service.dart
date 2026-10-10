import '../models/provider_document_correction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account_roles.dart';
import 'auth_service.dart';

class ProviderVerificationService {
  final db = FirebaseFirestore.instance;
  Future<void> continueAsDriver() async {
    if (AuthService.independentRoleAuth) {
      await AuthService().signOut();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified)
      throw StateError('Verify your email first.');
    final ref = db.collection('users').doc(user.uid);
    await db.runTransaction((tx) async {
      final profile = (await tx.get(ref)).data();
      tx.update(ref, {
        'roles': {...accountRoles(profile), 'driver'}.toList(),
        'lastRole': 'driver',
        'online': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> withdraw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified)
      throw StateError('Verify your email first.');
    final ref = db.collection('providerApplications').doc(user.uid);
    final moderationRef = db.collection('accountModeration').doc(user.uid);
    await db.runTransaction((tx) async {
      final application = (await tx.get(ref)).data();
      final moderation = (await tx.get(moderationRef)).data();
      if (application == null ||
          application['applicationStatus'] == 'withdrawn' ||
          moderation?['verification'] == 'verified' ||
          moderation?['verification'] == 'rejected') {
        throw StateError('This application is no longer waiting for review.');
      }
      tx.update(ref, {
        'applicationStatus': 'withdrawn',
        'withdrawnAt': FieldValue.serverTimestamp(),
      });
      tx.update(db.collection('users').doc(user.uid), {
        'online': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitCorrections({
    required int revision,
    required Map<String, String> replacements,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified)
      throw StateError('Verify your email first.');
    await user.getIdToken(true);
    final ref = db.collection('providerApplications').doc(user.uid);
    await db.runTransaction((tx) async {
      final previous = (await tx.get(ref)).data();
      final moderation = (await tx.get(
        db.collection('accountModeration').doc(user.uid),
      )).data();
      final request = ProviderDocumentCorrection.active(previous, moderation);
      if (request == null || request.revision != revision)
        throw StateError(
          'This correction request changed. Refresh and try again.',
        );
      final updated = request.replaceDocuments(previous!, replacements);
      tx.set(ref, {
        ...updated,
        'revision': revision + 1,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submit(Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your email before submitting your application.');
    }
    await user.getIdToken(true);
    final ref = db.collection('providerApplications').doc(user.uid);
    await db.runTransaction((tx) async {
      final previous = (await tx.get(ref)).data();
      final moderation = (await tx.get(
        db.collection('accountModeration').doc(user.uid),
      )).data();
      if (ProviderDocumentCorrection.active(previous, moderation) != null)
        throw StateError('Use the requested document correction form.');
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
