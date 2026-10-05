import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final db = FirebaseFirestore.instance;
  Future<void> requireAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final token = await user.getIdTokenResult(true);
    final access = await db.collection('adminAccess').doc(user.uid).get();
    if (access.data()?['enabled'] != true)
      throw StateError('Admin access has not been provisioned or was revoked.');
    if (!user.emailVerified || token.claims?['admin'] != true)
      throw StateError('Verified admin access is required.');
  }

  Future<void> addPrivateNote(String kind, String target, String text) async {
    await requireAdmin();
    await db.collection('adminNotes').add({
      'kind': kind,
      'target': target,
      'text': text.trim(),
      'actor': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moderate(
    String uid, {
    String? verification,
    String? status,
    bool? flagged,
    required String reason,
  }) async {
    await requireAdmin();
    final actor = FirebaseAuth.instance.currentUser!.uid;
    final ref = db.collection('accountModeration').doc(uid);
    final audit = db.collection('adminAudit').doc();
    await db.runTransaction((tx) async {
      final before = (await tx.get(ref)).data() ?? <String, dynamic>{};
      final directory = await tx.get(
        db.collection('providerDirectory').doc(uid),
      );
      final after = <String, dynamic>{
        'status': status ?? before['status'] ?? 'active',
        'verification': verification ?? before['verification'] ?? 'pending',
        'flagged': flagged ?? before['flagged'] ?? false,
        'reason': reason.trim(),
        'updatedBy': actor,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': audit.id,
      };
      if (verification == 'rejected') after['status'] = 'suspended';
      tx.set(ref, after);
      if (directory.exists &&
          (after['status'] == 'suspended' ||
              after['verification'] == 'rejected')) {
        tx.update(directory.reference, {
          'online': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(audit, {
        'kind': 'account',
        'target': uid,
        'actor': actor,
        'reason': reason.trim(),
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reviewComplaint(
    String requestId, {
    required String status,
    required String priority,
    required String decision,
  }) async {
    await requireAdmin();
    final actor = FirebaseAuth.instance.currentUser!.uid;
    final ref = db.collection('complaintReviews').doc(requestId);
    final audit = db.collection('adminAudit').doc();
    await db.runTransaction((tx) async {
      final before = (await tx.get(ref)).data() ?? <String, dynamic>{};
      final after = {
        'status': status,
        'priority': priority,
        'assignedTo': actor,
        'decision': decision.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': audit.id,
      };
      tx.set(ref, after);
      tx.set(audit, {
        'kind': 'complaint',
        'target': requestId,
        'actor': actor,
        'reason': decision.trim(),
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
