// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

class TestAuth extends FirebaseAuthPlatform {
  final events = StreamController<UserPlatform?>.broadcast();
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform? get currentUser => null;
  @override
  Stream<UserPlatform?> authStateChanges() => events.stream;
}

class TestUser extends UserPlatform {
  TestUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        TestFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'deleted',
            email: 'old@example.com',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class TestFactor extends MultiFactorPlatform {
  TestFactor(super.auth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  testWidgets('access check preserves login route and navigator on sign-out', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final auth = TestAuth();
    FirebaseAuthPlatform.instance = auth;
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        builder: (_, child) => AccountAccessGate(child: child!),
        home: const Scaffold(body: Text('Initial route')),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Sign in form')),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = key.currentState;
    auth.events.add(TestUser(auth));
    await tester.pump();
    await tester.pump();
    expect(key.currentState, same(navigator));
    auth.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Sign in form'), findsOneWidget);
    expect(key.currentState, same(navigator));
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.events.close();
  });
}
