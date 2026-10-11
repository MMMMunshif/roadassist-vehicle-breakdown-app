// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

class _Auth extends FirebaseAuthPlatform {
  late final UserPlatform user = _User(this);
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;
  @override
  UserPlatform get currentUser => user;
  @override
  Stream<UserPlatform?> userChanges() => Stream.value(user);
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth) : super(auth, _MultiFactor(auth),
    InternalUserDetails(userInfo: InternalUserInfo(
      uid: 'unverified-driver', email: 'unverified@example.com',
      isAnonymous: false, isEmailVerified: false,
    ), providerData: []));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _Auth();
  });

  testWidgets('direct driver dashboard entry is blocked for an unverified account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverShell()));
    await tester.pumpAndSettle();
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
    expect(find.byType(DriverHomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unverified provider must verify email before document submission', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProviderShell()));
    await tester.pumpAndSettle();
    final verification = tester.widget<EmailVerificationScreen>(find.byType(EmailVerificationScreen));
    expect(verification.role, 'provider');
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(ProviderVerificationScreen), findsNothing);
    expect(find.byType(ApprovedProviderShell), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
