// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

class _SignedOutAuth extends FirebaseAuthPlatform {
  _SignedOutAuth() : super(appInstance: Firebase.app());
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuth();
  });
  for (final login in [true, false]) {
    testWidgets(
      'guest entry opens emergency help without verification: login=$login',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(Brightness.light),
            home: login ? const LoginScreen() : const RoleSelectionScreen(),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.text(
          login
              ? 'Need urgent help? Continue as guest'
              : 'Emergency Guest Access',
        );
        await tester.scrollUntilVisible(
          entry,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(entry), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(GuestAccessScreen), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Emergency help'), 150);
        await tester.tap(find.text('Emergency help'));
        await tester.pumpAndSettle();
        expect(find.byType(EmergencyScreen), findsOneWidget);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(EmergencyScreen), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets('emergency numbers available signed out in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoadAssistTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const EmergencyScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Call 1990'), 150);
      expect(find.text('1990'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Call 117'), 250);
      expect(find.text('Call 117'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
