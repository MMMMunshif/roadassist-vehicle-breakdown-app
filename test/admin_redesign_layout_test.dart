// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

bool populated = false;
Map<String, Object?>? fixture(String path) {
  if (!populated) return null;
  if (path == 'adminAccess/admin') return {'role': 'super_admin'};
  if (path == 'users/id')
    return {
      'displayName': 'Provider with a long full name',
      'email': 'provider@example.com',
      'role': 'provider',
      'roles': ['provider', 'driver'],
      'phone': '0771234567',
      'services': ['General Mechanic'],
    };
  if (path == 'accountModeration/id')
    return {'status': 'active', 'verification': 'pending'};
  if (path == 'providerApplications/id')
    return {
      'applicationStatus': 'submitted',
      'legalName': 'Provider with a long full name',
      'revision': 1,
      'services': ['General Mechanic'],
      'documents': <String, Object?>{},
    };
  if (path == 'requests/id')
    return {
      'driverName': 'Driver with a long full name',
      'providerName': 'Provider with a long full name',
      'issues': ['General Mechanic'],
      'status': 'arrived',
      'locationLabel': 'A long address in Nugegoda, Colombo',
      'estimatedCost': 5000,
    };
  if (path == 'requests/id/disputes/id')
    return {
      'status': 'open',
      'reason': 'A service complaint requiring administrative review',
      'description': 'The driver requested a review of the service charge.',
    };
  if (path == 'adminAudit/id')
    return {
      'kind': 'verification',
      'actor': 'Administrator',
      'reason': 'Documents reviewed',
      'target': 'id',
    };
  return null;
}

class _Auth extends FirebaseAuthPlatform {
  _Auth() : super(appInstance: Firebase.app());
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _User(this);
}

class _Mfa extends MultiFactorPlatform {
  _Mfa(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _Mfa(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'admin',
            email: 'admin@example.com',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _Store extends FirebaseFirestorePlatform {
  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;
  @override
  CollectionReferencePlatform collection(String path) =>
      _Collection(this, path);
  @override
  QueryPlatform collectionGroup(String path) => _Collection(this, path);
  @override
  DocumentReferencePlatform doc(String path) => _Document(this, path);
}

class _Collection extends CollectionReferencePlatform {
  _Collection(super.firestore, super.path) {
    parameters.addAll({
      'where': <List<dynamic>>[],
      'orderBy': <List<dynamic>>[],
    });
  }
  @override
  QueryPlatform limit(int limit) => this;
  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) => this;
  @override
  QueryPlatform where(List<List<dynamic>> conditions) => this;
  @override
  QueryPlatform whereFilter(FilterPlatformInterface filter) => this;
  @override
  DocumentReferencePlatform doc([String? path]) =>
      _Document(firestore, '${this.path}/${path ?? 'id'}');
  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) => Stream.value(
    QuerySnapshotPlatform(
      [
        if (fixture(
              path == 'disputes' ? 'requests/id/disputes/id' : '$path/id',
            ) !=
            null)
          DocumentSnapshotPlatform(
            firestore,
            path == 'disputes' ? 'requests/id/disputes/id' : '$path/id',
            fixture(
              path == 'disputes' ? 'requests/id/disputes/id' : '$path/id',
            ),
            InternalSnapshotMetadata(
              hasPendingWrites: false,
              isFromCache: false,
            ),
          ),
      ],
      [],
      SnapshotMetadataPlatform(false, false),
    ),
  );
}

class _Document extends DocumentReferencePlatform {
  _Document(super.firestore, super.path);
  DocumentSnapshotPlatform get value => DocumentSnapshotPlatform(
    firestore,
    path,
    fixture(path),
    InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
  );
  @override
  Future<DocumentSnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async => value;
  @override
  Stream<DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) => Stream.value(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseFirestorePlatform.instance = _Store();
    FirebaseAuthPlatform.instance = _Auth();
  });
  setUp(() {
    populated = false;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  final pages = <String, Widget>{
    'Dashboard': AdminDashboardScreen(onSignOut: () async {}),
    'Overview': const AdminOverviewScreen(),
    'Providers': const AdminProvidersScreen(),
    'Users': const AdminUsersScreen(),
    'Complaints': const AdminComplaintsScreen(),
    'Jobs': const AdminJobsScreen(),
    'Audit': const AdminAuditScreen(),
    'Operations': const AdminOperationsScreen(),
    'Payments': const AdminPaymentsScreen(),
    'Reports': const AdminReportsScreen(),
    'Settings': const AdminSettingsScreen(),
    'Admin team': const AdminTeamScreen(),
    'Job detail': const AdminJobMonitorScreen(requestId: 'id'),
  };
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in pages.entries) {
        testWidgets('Admin ${entry.key} at 320/$scale/${brightness.name}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildRoadAssistTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RaAdminScaffold(body: entry.value),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            for (var i = 0; i < 8; i++) {
              await tester.drag(scrollable.first, const Offset(0, -400));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final brightness in Brightness.values) {
    for (final name in [
      'Providers',
      'Complaints',
      'Audit',
      'Jobs',
      'Reports',
    ]) {
      testWidgets('Populated $name and detail in ${brightness.name}', (
        tester,
      ) async {
        populated = true;
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: RaAdminScaffold(body: pages[name]!),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final target = switch (name) {
          'Providers' => find.text('Provider with a long full name'),
          'Complaints' => find.text(
            'A service complaint requiring administrative review',
          ),
          'Audit' => find.text('Verification'),
          'Jobs' => find.textContaining('Driver with a long full name'),
          _ => find.text('Loaded job report'),
        };
        await tester.scrollUntilVisible(
          target,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: .3);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (name != 'Reports') {
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        for (var i = 0; i < 15; i++) {
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isEmpty) break;
          await tester.drag(scroll.first, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Every admin workspace stays reachable from More', (
    tester,
  ) async {
    var selected = -1;
    final names = [
      'Overview',
      'Providers',
      'Users',
      'Complaints',
      'Jobs',
      'Audit',
      'Operations',
      'Payments',
      'Reports',
      'Settings',
      'Admin team',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: RaAdminScaffold(
          bottomNavigationBar: AdminNavigationBar(
            selected: 0,
            destinations: [
              for (var i = 0; i < names.length; i++)
                (index: i, label: names[i], icon: Icons.dashboard_outlined),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    for (final name in names) {
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, name),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(name).last, findsOneWidget);
    }
    await tester.tap(find.text('Admin team'));
    await tester.pumpAndSettle();
    expect(selected, 10);
  });
  testWidgets(
    'Audit identities and field labels are readable and changes remain visible',
    (tester) async {
      populated = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoadAssistTheme(Brightness.light),
          home: const AdminAuditDetailScreen(
            data: {
              'kind': 'account',
              'actor': 'id',
              'target': 'id',
              'reason': 'Identity documents reviewed',
              'before': <String, dynamic>{},
              'after': {
                'verification': 'verified',
                'verificationRevision': 1,
                'verificationChecks': ['identity', 'face'],
                'validUntil': 'Next year',
                'updatedBy': 'id',
                'lastAuditId': 'reference',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Provider approved'), findsWidgets);
      expect(
        find.textContaining('Provider with a long full name'),
        findsWidgets,
      );
      await tester.scrollUntilVisible(
        find.text('After'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Verification Revision: 1'), findsOneWidget);
      expect(find.textContaining(r'$1'), findsNothing);
      expect(
        find.textContaining('No previous record (first recorded decision)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
