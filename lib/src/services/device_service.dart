import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class DeviceService {
  DeviceService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  static const webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
  static StreamSubscription<String>? _tokenSubscription;
  static String? _registeredToken;
  static String? _ownerId;
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  Future<void> registerCurrentDevice({bool requestPermission = false}) async {
    try {
      await _registerCurrentDevice(requestPermission: requestPermission);
    } catch (_) {
      if (requestPermission) rethrow;
    }
  }

  Future<void> _registerCurrentDevice({required bool requestPermission}) async {
    final user = _auth.currentUser;
    if (user == null && !requestPermission) return;
    if (user == null) throw StateError('Sign in to enable notifications.');
    if (!await _messaging.isSupported())
      throw StateError('This device does not support push notifications.');
    if (kIsWeb && webVapidKey.isEmpty) {
      if (requestPermission)
        throw StateError(
          'Browser notifications are not configured yet. Contact the app administrator.',
        );
      return;
    }
    final settings = requestPermission
        ? await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await _messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      if (requestPermission)
        throw StateError(
          'Notifications are blocked. Allow them in browser or device settings and try again.',
        );
      return;
    }
    if (!requestPermission) {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (profile.data()?['pushEnabled'] == false) return;
    }
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? webVapidKey : null,
    );
    if (token == null)
      throw StateError('Could not register this device. Try again.');
    if (_auth.currentUser?.uid != user.uid) return;
    await _tokenSubscription?.cancel();
    _ownerId = user.uid;
    _registeredToken = token;
    await _saveToken(user.uid, token);
    if (requestPermission)
      await _firestore.collection('users').doc(user.uid).update({
        'pushEnabled': true,
      });
    _tokenSubscription = _messaging.onTokenRefresh.listen((value) {
      if (_ownerId == user.uid && _auth.currentUser?.uid == user.uid) {
        _registeredToken = value;
        unawaited(_saveToken(user.uid, value).catchError((Object error) {}));
      }
    });
  }

  Future<void> unregisterCurrentDevice() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    final user = _auth.currentUser;
    try {
      if (user != null && (!kIsWeb || webVapidKey.isNotEmpty)) {
        final token = _ownerId == user.uid
            ? _registeredToken
            : await _messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
        if (token != null)
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('devices')
              .doc(token.replaceAll('/', '_'))
              .delete();
        await _messaging.deleteToken();
      }
    } finally {
      _ownerId = null;
      _registeredToken = null;
    }
  }

  Future<void> disableNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'pushEnabled': false,
    });
    await unregisterCurrentDevice();
  }

  Future<void> _saveToken(String uid, String token) async {
    if (_auth.currentUser?.uid != uid) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(token.replaceAll('/', '_'))
        .set({
          'token': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
