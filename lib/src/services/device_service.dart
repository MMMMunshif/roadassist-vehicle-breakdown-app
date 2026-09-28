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

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> registerCurrentDevice() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(user.uid, token);
      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen(
        (value) => _saveToken(user.uid, value),
      );
    } catch (_) {
      // Web push needs a VAPID key; realtime Firestore remains available.
    }
  }

  Future<void> _saveToken(String userId, String token) => _firestore
      .collection('users')
      .doc(userId)
      .collection('devices')
      .doc(token.replaceAll('/', '_'))
      .set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
