// Fake plugin interfaces are used only for isolated AuthService tests.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/account_roles.dart';
import 'package:road_assist/src/services/auth_service.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'same-user';
  @override
  String get email => 'same@example.com';
  @override
  bool get emailVerified => true;
}

class Credential extends Fake implements UserCredential {
  @override
  User get user => TestUser();
}

class TestAuth extends Fake implements FirebaseAuth {
  bool signedOut = false;
  @override
  User get currentUser => TestUser();
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw FirebaseAuthException(code: 'email-already-in-use');
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (password != 'Existing123') {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return Credential();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.values);
  final Map<String, dynamic>? values;
  @override
  bool get exists => values != null;
  @override
  Map<String, dynamic>? data() => values;
}

class Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  Ref(this.db, this.collectionName);
  final TestDb db;
  final String collectionName;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async =>
      Snapshot(collectionName == 'users' ? db.profile : db.confirmations);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    db.profile.addAll(data);
  }
}

class Col extends Fake implements CollectionReference<Map<String, dynamic>> {
  Col(this.db, this.name);
  final TestDb db;
  final String name;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => Ref(db, name);
}

class TestDb extends Fake implements FirebaseFirestore {
  TestDb(String role)
    : profile = {
        'role': role,
        'displayName': 'Original Name',
        'phone': '+94771234567',
        'email': 'same@example.com',
      };
  final Map<String, dynamic> profile;
  Map<String, dynamic>? confirmations;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      Col(this, path);
}

void main() {
  test(
    'existing verified role stays usable while additional role awaits email confirmation',
    () async {
      final db = TestDb('provider');
      db.profile.addAll({
        'roles': ['provider', 'driver'],
        'roleEmailRequired': ['driver'],
      });
      final service = AuthService(
        independentRoleAuthEnabled: false,
        auth: TestAuth(),
        firestore: db,
      );
      expect(await service.isRoleEmailVerified('provider'), true);
      expect(await service.isRoleEmailVerified('driver'), false);
      db.confirmations = {
        'driver': {'email': 'wrong@example.com'},
      };
      expect(await service.isRoleEmailVerified('driver'), false);
      db.confirmations = {
        'driver': {'email': 'same@example.com'},
      };
      expect(await service.isRoleEmailVerified('driver'), true);
    },
  );
  test('legacy primary role is retained and last role must be enrolled', () {
    expect(accountRoles({'role': 'driver'}), ['driver']);
    expect(
      accountRoles({
        'role': 'driver',
        'roles': ['provider', 'admin'],
      }),
      ['driver', 'provider'],
    );
    expect(accountLastRole({'role': 'driver', 'lastRole': 'admin'}), 'driver');
    expect(
      accountLastRole({
        'role': 'driver',
        'roles': ['driver', 'provider'],
        'lastRole': 'provider',
      }),
      'provider',
    );
  });
  for (final first in ['driver', 'provider']) {
    test(
      'second-role registration reuses $first account and preserves profile',
      () async {
        final db = TestDb(first), auth = TestAuth();
        final other = first == 'driver' ? 'provider' : 'driver';
        final result =
            await AuthService(
              independentRoleAuthEnabled: false,
              auth: auth,
              firestore: db,
            ).register(
              email: 'same@example.com',
              password: 'Existing123',
              role: other,
              displayName: 'Replacement Name',
              phone: '+94770000000',
            );
        expect(result.user!.uid, 'same-user');
        expect(accountRoles(db.profile), containsAll(['driver', 'provider']));
        expect(db.profile['role'], first);
        expect(db.profile['lastRole'], other);
        expect(db.profile['roleEmailRequired'], [other]);
        expect(db.profile['displayName'], 'Original Name');
        expect(db.profile['phone'], '+94771234567');
        expect(db.profile['online'], false);
        expect(auth.signedOut, false);
      },
    );
  }
  test('wrong existing password cannot enroll another role', () async {
    final db = TestDb('driver');
    await expectLater(
      AuthService(
        independentRoleAuthEnabled: false,
        auth: TestAuth(),
        firestore: db,
      ).register(
        email: 'same@example.com',
        password: 'Wrong123',
        role: 'provider',
        displayName: 'Name',
        phone: '+94771234567',
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(accountRoles(db.profile), ['driver']);
  });
  test('same-role duplicate signup still reports existing account', () async {
    final db = TestDb('driver');
    await expectLater(
      AuthService(
        independentRoleAuthEnabled: false,
        auth: TestAuth(),
        firestore: db,
      ).register(
        email: 'same@example.com',
        password: 'Existing123',
        role: 'driver',
        displayName: 'Name',
        phone: '+94771234567',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'email-already-in-use',
        ),
      ),
    );
    expect(accountRoles(db.profile), ['driver']);
  });
}
