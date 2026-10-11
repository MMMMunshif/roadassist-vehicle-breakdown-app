import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';

// The Admin Android package reads its own google-services.json native options.
// Reusing the normal app's explicit appId here would bind it to the wrong app.
FirebaseOptions? get _startupFirebaseOptions =>
    const bool.fromEnvironment('ADMIN_PORTAL') &&
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? null
    : DefaultFirebaseOptions.currentPlatform;

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: _startupFirebaseOptions);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _startupFirebaseOptions);
  if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  runApp(const RoadAssistApp());
}
