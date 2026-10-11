import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_assist/src/services/auth_service.dart';

class Store extends Fake implements FirebaseFirestore {}

class Account extends Fake implements User {
  @override
  String get uid => 'separate-role-uid';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
}

class Credential extends Fake implements UserCredential {
  @override
  User get user => Account();
}

class NativeAuth extends Fake implements FirebaseAuth {
  int calls = 0;
  String? email;
  String? password;
  @override
  User get currentUser => Account();
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    calls++;
    this.email = email;
    this.password = password;
    return Credential();
  }
}

void main() {
  for (final role in ['driver', 'provider']) {
    test(
      'new $role uses native role password and requests its verification',
      () async {
        final auth = NativeAuth();
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['role'], role);
          if (request.url.path.endsWith('/role-auth')) {
            expect(body['email'], 'same@example.com');
            expect(body['password'], '${role}123Password');
            expect(body['action'], 'register');
            return http.Response(
              jsonEncode({'authEmail': '$role@roles.roadassist.invalid'}),
              201,
            );
          }
          expect(
            request.url.path.endsWith('/request-email-verification'),
            isTrue,
          );
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('{"ok":true}', 200);
        });
        final service = AuthService(
          auth: auth,
          firestore: Store(),
          httpClient: client,
          independentRoleAuthEnabled: true,
        );
        await service.register(
          email: 'same@example.com',
          password: '${role}123Password',
          role: role,
          displayName: 'Role User',
          phone: '+94771234567',
        );
        expect(auth.email, '$role@roles.roadassist.invalid');
        expect(auth.password, '${role}123Password');
        expect(auth.calls, 1);
        expect(requests, 2);
        expect(service.verificationEmailDeliveryFailed, isFalse);
        client.close();
      },
    );
  }
  test(
    'duplicate role signup cannot sign in or overwrite the account',
    () async {
      final auth = NativeAuth();
      final client = MockClient(
        (_) async => http.Response('{"code":"email-already-in-use"}', 409),
      );
      final service = AuthService(
        auth: auth,
        firestore: Store(),
        httpClient: client,
        independentRoleAuthEnabled: true,
      );
      await expectLater(
        service.register(
          email: 'same@example.com',
          password: 'New123Password',
          role: 'driver',
          displayName: 'Role User',
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
      expect(auth.calls, 0);
      client.close();
    },
  );
}
