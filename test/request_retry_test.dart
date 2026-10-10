// ignore_for_file: depend_on_referenced_packages, subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/services/request_service.dart';
import 'deleted_account_login_test.dart' as mocks;
import 'request_draft_test.dart' as drafts;

class Auth extends mocks.TestAuth {
  @override
  User get currentUser => mocks.TestUser();
}

class Connection extends ConnectivityPlatform {
  Connection(this.offline);
  final bool offline;
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    offline ? ConnectivityResult.none : ConnectivityResult.wifi,
  ];
}

class Store extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'requests');
    return Collection();
  }
}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'stable-id');
    return Document();
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => QueryResult();
}

class Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class QueryResult extends Fake implements Query<Map<String, dynamic>> {
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    expect(isEqualTo, 'stable-id');
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    return Snapshot();
  }
}

class Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [Job()];
}

class Job extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'stable-id';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ConnectivityPlatform original;
  setUp(() {
    original = ConnectivityPlatform.instance;
  });
  tearDown(() {
    ConnectivityPlatform.instance = original;
  });
  test('retry returns existing server request without any writes', () async {
    ConnectivityPlatform.instance = Connection(false);
    final service = RequestService(auth: Auth(), firestore: Store());
    expect(
      await service.createRequest(
        drafts.sampleDraft(),
        submissionId: 'stable-id',
      ),
      'stable-id',
    );
  });
  test('offline creation is rejected before any database access', () async {
    ConnectivityPlatform.instance = Connection(true);
    final service = RequestService(auth: Auth(), firestore: Store());
    await expectLater(
      service.createRequest(drafts.sampleDraft(), submissionId: 'stable-id'),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  });
}
