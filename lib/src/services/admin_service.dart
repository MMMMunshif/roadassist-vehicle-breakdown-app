import 'dart:async';
import '../models/provider_document_correction.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.accessTimeout = const Duration(seconds: 12),
    this.decisionTimeout = const Duration(seconds: 30),
  }) : db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth _auth;
  final Duration accessTimeout;
  final Duration decisionTimeout;
  Future<void> requireAdmin() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final token = await user.getIdTokenResult(true).timeout(accessTimeout);
    final access = await db
        .collection('adminAccess')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server))
        .timeout(accessTimeout);
    if (access.data()?['enabled'] != true)
      throw StateError('Admin access has not been provisioned or was revoked.');
    if (!user.emailVerified || token.claims?['admin'] != true)
      throw StateError('Verified admin access is required.');
  }

  Future<void> deleteAccount(
    String uid,
    String reason,
    String confirmation,
  ) async {
    await requireAdmin();
    const endpoint = String.fromEnvironment('ADMIN_ACCOUNT_DELETE_API_URL');
    if (endpoint.isEmpty || Uri.tryParse(endpoint)?.scheme != 'https') {
      throw StateError(
        'Deploy and configure the private account deletion endpoint first.',
      );
    }
    final token = await _auth.currentUser!
        .getIdToken(true)
        .timeout(accessTimeout);
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'uid': uid,
            'reason': reason,
            'confirmation': confirmation,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      final result = jsonDecode(response.body);
      throw StateError(
        result['message'] as String? ?? 'Account deletion failed.',
      );
    }
  }

  Future<void> addPrivateNote(String kind, String target, String text) async {
    await requireAdmin();
    await db.collection('adminNotes').add({
      'kind': kind,
      'target': target,
      'text': text.trim(),
      'actor': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moderate(
    String uid, {
    String? verification,
    String? status,
    bool? flagged,
    required String reason,
    int? verificationRevision,
    DateTime? validUntil,
    List<String>? verificationChecks,
    List<String>? correctionDocuments,
    int? expectedApplicationRevision,
  }) async {
    await requireAdmin();
    final actor = _auth.currentUser!.uid;
    final ref = db.collection('accountModeration').doc(uid);
    final audit = db.collection('adminAudit').doc();
    final clock = Stopwatch()..start();
    void checkDeadline() {
      if (clock.elapsed >= decisionTimeout) {
        throw TimeoutException(
          'Decision confirmation timed out. Refresh the review status before retrying.',
        );
      }
    }

    await db
        .runTransaction(
          (tx) async {
            checkDeadline();
            final before = (await tx.get(ref)).data() ?? <String, dynamic>{};
            if (verification == 'verified' || correctionDocuments != null) {
              final application = (await tx.get(
                db.collection('providerApplications').doc(uid),
              )).data();
              if (verification == 'verified' &&
                  ProviderDocumentCorrection.active(application, before) !=
                      null)
                throw StateError(
                  'Wait for the requested documents to be resubmitted.',
                );
              if (application == null ||
                  application['applicationStatus'] == 'withdrawn' ||
                  application['revision'] !=
                      (correctionDocuments != null
                          ? expectedApplicationRevision
                          : verificationRevision)) {
                throw StateError(
                  'Application withdrawn or changed. Refresh before reviewing.',
                );
              }
            }

            final directory = await tx.get(
              db.collection('providerDirectory').doc(uid),
            );
            if (correctionDocuments != null &&
                (verification != 'pending' ||
                    correctionDocuments.isEmpty ||
                    correctionDocuments.length > 6 ||
                    correctionDocuments.toSet().length !=
                        correctionDocuments.length ||
                    !correctionDocuments.every(
                      ProviderDocumentCorrection.labels.containsKey,
                    ) ||
                    reason.trim().length < 10 ||
                    reason.trim().length > 500)) {
              throw StateError(
                'Select documents and enter clear instructions (10-500 characters).',
              );
            }
            final after = <String, dynamic>{
              if (correctionDocuments != null)
                'correctionRequest': {
                  'revision': expectedApplicationRevision,
                  'documents': correctionDocuments,
                  'requestedAt': FieldValue.serverTimestamp(),
                },
              if (verification == null && before['correctionRequest'] != null)
                'correctionRequest': before['correctionRequest'],
              if (before['verificationRevision'] != null)
                'verificationRevision': before['verificationRevision'],
              if (before['validUntil'] != null)
                'validUntil': before['validUntil'],
              if (before['verificationChecks'] != null)
                'verificationChecks': before['verificationChecks'],
              if (verificationRevision != null)
                'verificationRevision': verificationRevision,
              if (validUntil != null)
                'validUntil': Timestamp.fromDate(validUntil),
              if (verificationChecks != null)
                'verificationChecks': verificationChecks,
              'status': status ?? before['status'] ?? 'active',
              'verification':
                  verification ?? before['verification'] ?? 'pending',
              'flagged': flagged ?? before['flagged'] ?? false,
              'reason': reason.trim(),
              'updatedBy': actor,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastAuditId': audit.id,
            };
            if (verification == 'rejected') after['status'] = 'suspended';
            checkDeadline();
            tx.set(ref, after);
            if (directory.exists &&
                (after['status'] == 'suspended' ||
                    after['verification'] != 'verified')) {
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
          },
          timeout: decisionTimeout,
          maxAttempts: 3,
        )
        .timeout(decisionTimeout);
  }

  Future<void> reviewComplaint(
    String requestId, {
    required String status,
    required String priority,
    required String decision,
    DateTime? dueAt,
  }) async {
    await requireAdmin();
    final actor = _auth.currentUser!.uid;
    final ref = db.collection('complaintReviews').doc(requestId);
    final audit = db.collection('adminAudit').doc();
    await db.runTransaction((tx) async {
      final before = (await tx.get(ref)).data() ?? <String, dynamic>{};
      final after = {
        'status': status,
        'priority': priority,
        'assignedTo': actor,
        'decision': decision.trim(),
        if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt),
        if (dueAt == null && before['dueAt'] != null) 'dueAt': before['dueAt'],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': audit.id,
      };
      tx.set(ref, after);
      tx.set(ref.collection('history').doc(audit.id), {
        'status': status,
        'decision': decision.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
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

  Future<void> sendApprovalEmail(String uid) async {
    await requireAdmin();
    final token = await _auth.currentUser!
        .getIdToken(true)
        .timeout(accessTimeout);
    const endpoint = String.fromEnvironment('PROVIDER_APPROVAL_EMAIL_API_URL');
    if (endpoint.isEmpty || Uri.tryParse(endpoint)?.scheme != 'https') {
      throw StateError(
        'Configure your deployed approval-email endpoint first.',
      );
    }
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'uid': uid}),
        )
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200)
      throw StateError('Approval email service unavailable.');
  }

  Future<void> saveSettings({
    required bool maintenance,
    required String notice,
    required String coverage,
    required List<String> services,
    required String reason,
  }) async {
    await requireAdmin();
    final ref = db.collection('appSettings').doc('operations'),
        audit = db.collection('adminAudit').doc();
    final actor = _auth.currentUser!.uid;
    await db.runTransaction((tx) async {
      final before = (await tx.get(ref)).data() ?? <String, dynamic>{};
      final after = {
        'maintenance': maintenance,
        'notice': notice,
        'coverage': coverage,
        'enabledServices': services,
        'reason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
        'lastAuditId': audit.id,
      };
      tx.set(ref, after);
      tx.set(audit, {
        'kind': 'settings',
        'target': 'operations',
        'actor': actor,
        'reason': reason,
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
