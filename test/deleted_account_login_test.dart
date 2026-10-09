import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/services/auth_service.dart';

class TestAuth extends Fake implements FirebaseAuth {
  int signOuts = 0;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => TestCredential();
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class TestCredential extends Fake implements UserCredential {
  @override
  User get user => TestUser();
}

class TestUser extends Fake implements User {
  @override
  String get uid => 'deleted-account';
}

class TestStore extends Fake implements FirebaseFirestore {
  TestStore(this.fail);
  final bool fail;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TestCollection(fail);
}

class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  TestCollection(this.fail);
  final bool fail;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      TestDocument(fail);
}

class TestDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  TestDocument(this.fail);
  final bool fail;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    if (fail)
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    return MissingProfile();
  }
}

class MissingProfile extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => false;
}

void main() {
  for (final role in ['driver', 'provider']) {
    test('$role deleted profile rejects login and clears session', () async {
      final auth = TestAuth();
      await expectLater(
        AuthService(
          auth: auth,
          firestore: TestStore(false),
        ).signIn(email: 'old@example.com', password: 'password', role: role),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'account-not-found',
          ),
        ),
      );
      expect(auth.signOuts, 1);
    });
  }
  test('profile read failure clears newly authenticated session', () async {
    final auth = TestAuth();
    await expectLater(
      AuthService(
        auth: auth,
        firestore: TestStore(true),
      ).signIn(email: 'old@example.com', password: 'password', role: 'driver'),
      throwsA(isA<FirebaseException>()),
    );
    expect(auth.signOuts, 1);
  });
}
