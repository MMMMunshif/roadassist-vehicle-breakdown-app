// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/services/admin_service.dart';

class WaitingUser extends Fake implements User {
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) =>
      Completer<IdTokenResult>().future;
}

class TestUser extends Fake implements User {
  @override
  String get uid => 'admin';
}

class TestAuth extends Fake implements FirebaseAuth {
  TestAuth(this.user);
  final User user;
  @override
  User get currentUser => user;
}

class TestRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  @override
  String get id => 'audit';
}

class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => TestRef();
}

class TestTransaction extends Fake implements Transaction {}

class WaitingDb extends Fake implements FirebaseFirestore {
  WaitingDb({this.delayCallback = false});
  final bool delayCallback;
  bool? callbackRejected;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TestCollection();
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (!delayCallback) return Completer<T>().future;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    try {
      return await transactionHandler(TestTransaction());
    } on TimeoutException {
      callbackRejected = true;
      rethrow;
    }
  }
}

class ReviewService extends AdminService {
  ReviewService(WaitingDb db)
    : super(
        firestore: db,
        auth: TestAuth(TestUser()),
        decisionTimeout: const Duration(milliseconds: 15),
      );
  @override
  Future<void> requireAdmin() async {}
}

void main() {
  test(
    'admin token refresh does not leave approval waiting indefinitely',
    () async {
      final service = AdminService(
        firestore: WaitingDb(),
        auth: TestAuth(WaitingUser()),
        accessTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        service.requireAdmin(),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test(
    'non-returning approval transaction reports an uncertain timeout',
    () async {
      await expectLater(
        ReviewService(
          WaitingDb(),
        ).moderate('provider', reason: 'Checked submitted identity.'),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test(
    'transaction callback that starts after timeout cannot write a decision',
    () async {
      final db = WaitingDb(delayCallback: true);
      await expectLater(
        ReviewService(
          db,
        ).moderate('provider', reason: 'Checked submitted identity.'),
        throwsA(isA<TimeoutException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(db.callbackRejected, true);
    },
  );
}
