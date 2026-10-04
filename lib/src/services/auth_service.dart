import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'device_service.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static const _passwordResetApiUrl = String.fromEnvironment(
    'PASSWORD_RESET_API_URL',
    defaultValue:
        'https://vehiclebreakdownapp.vercel.app/api/request-password-reset',
  );
  static const _emailVerificationApiUrl = String.fromEnvironment(
    'EMAIL_VERIFICATION_API_URL',
    defaultValue:
        'https://vehiclebreakdownapp.vercel.app/api/request-email-verification',
  );

  Future<void> sendPasswordResetEmail(String email) async {
    if (_passwordResetApiUrl.isEmpty) {
      throw FirebaseAuthException(
        code: 'password-reset-service-unconfigured',
        message: 'Password reset service is not configured for this build.',
      );
    }
    final response = await http
        .post(
          Uri.parse(_passwordResetApiUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'website': ''}),
        )
        .timeout(const Duration(seconds: 35));
    final body = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseAuthException(
        code: 'password-reset-service-error',
        message:
            body['message'] as String? ??
            'Unable to send the password reset email.',
      );
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final idToken = await user.getIdToken(true);
    final response = await http
        .post(
          Uri.parse(_emailVerificationApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 35));
    final body = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseAuthException(
        code: 'email-verification-service-error',
        message:
            body['message'] as String? ?? 'Unable to send verification email.',
      );
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentProfile() {
    final user = currentUser;
    if (user == null) throw StateError('Authentication is required.');
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCurrentProfile() {
    final user = currentUser;
    if (user == null) throw StateError('Authentication is required.');
    return _firestore.collection('users').doc(user.uid).get();
  }

  Future<void> restoreSessionServices() async {
    final user = currentUser;
    if (user == null) return;
    final profile = await getCurrentProfile();
    final role = profile.data()?['role'] as String?;
    if (role == null) return;
    _startBackgroundSetup(role);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOnlineProviders() =>
      _firestore
          .collection('providerDirectory')
          .where('online', isEqualTo: true)
          .snapshots();

  Future<void> syncProviderDirectory() async {
    final user = currentUser;
    if (user == null) return;
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data();
    if (data?['role'] != 'provider') return;
    final jobs = await _firestore
        .collection('requests')
        .where('providerId', isEqualTo: user.uid)
        .get();
    final completed = jobs.docs
        .where((job) => job.data()['status'] == 'completed')
        .toList();
    final ratings = completed
        .map((job) => job.data()['driverRating'])
        .whereType<num>()
        .map((rating) => rating.toDouble())
        .toList();
    final responseMinutes = jobs.docs
        .map((job) {
          final created = job.data()['createdAt'] as Timestamp?;
          final accepted = job.data()['acceptedAt'] as Timestamp?;
          if (created == null || accepted == null) return null;
          return accepted.toDate().difference(created.toDate()).inSeconds / 60;
        })
        .whereType<double>()
        .toList();
    await _firestore.collection('providerDirectory').doc(user.uid).set({
      'displayName':
          data?['displayName'] ?? user.displayName ?? 'Service Provider',
      'online': data?['online'] ?? true,
      'services': data?['services'] ?? const <String>[],
      'serviceRadius': data?['serviceRadius'] ?? '15 km from current location',
      'completedJobs': completed.length,
      'averageRating': ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length,
      'averageResponseMinutes': responseMinutes.isEmpty
          ? 0.0
          : responseMinutes.reduce((a, b) => a + b) / responseMinutes.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final activeJobs = jobs.docs.where(
      (job) => const [
        'accepted',
        'en_route',
        'arrived',
      ].contains(job.data()['status']),
    );
    if (activeJobs.isNotEmpty) {
      await _firestore.collection('providerDirectory').doc(user.uid).update({
        'activeRequestId': activeJobs.first.id,
      });
    }
  }

  Future<void> updateProviderDirectoryLocation({
    required double latitude,
    required double longitude,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('providerDirectory').doc(user.uid).set({
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setProviderOnline(bool online) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await syncProviderDirectory();
  }

  Future<void> updateCurrentProfile(Map<String, dynamic> values) async {
    final user = currentUser;
    if (user == null) return;
    final name = values['displayName'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }
    await _firestore.collection('users').doc(user.uid).set({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markNotificationsSeen() async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'notificationsSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final profile = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();
    if (!profile.exists || profile.data()?['role'] != role) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'wrong-role',
        message: 'This account is not registered as a $role.',
      );
    }
    _startBackgroundSetup(role);
    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String role,
    required String displayName,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(displayName.trim());
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'phone': phone.trim(),
      'role': role,
      'online': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await sendVerificationEmail();
    } catch (_) {
      // Account creation must remain usable when Firebase email delivery is
      // temporarily unavailable. Verification can be resent from the app.
    }
    return credential;
  }

  Future<void> deleteCurrentAccount({required String password}) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('Authentication is required.');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    final profileRef = _firestore.collection('users').doc(user.uid);
    final profile = await profileRef.get();
    final role = profile.data()?['role'] as String?;
    final devices = await profileRef.collection('devices').get();
    final batch = _firestore.batch();
    for (final device in devices.docs) {
      batch.delete(device.reference);
    }
    if (role == 'provider') {
      batch.delete(_firestore.collection('providerDirectory').doc(user.uid));
    }
    batch.delete(profileRef);
    await batch.commit();
    await user.delete();
  }

  void _startBackgroundSetup(String role) {
    unawaited(
      DeviceService()
          .registerCurrentDevice()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
    );
    if (role == 'provider') {
      unawaited(
        syncProviderDirectory()
            .timeout(const Duration(seconds: 10))
            .catchError((_) {}),
      );
    }
  }

  Future<void> signOut() async {
    final user = currentUser;
    if (user != null) {
      try {
        final profile = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (profile.data()?['role'] == 'provider') {
          await setProviderOnline(false);
        }
      } catch (_) {
        // Signing out must still work when Firestore is temporarily offline.
      }
    }
    await _auth.signOut();
  }
}
