// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/request_draft.dart';
import 'package:road_assist/src/services/request_draft_store.dart';

class TestConnection extends ConnectivityPlatform {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.none,
  ];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

void main() {
  testWidgets('offline review saves draft and reconnect does not auto-submit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final original = ConnectivityPlatform.instance;
    final connection = TestConnection();
    ConnectivityPlatform.instance = connection;
    addTearDown(() async {
      ConnectivityPlatform.instance = original;
      await connection.changes.close();
    });
    final draft = RequestDraft(
      issues: ['Flat Tyre'],
      vehicleType: 'Car',
      modelYear: 'Toyota 2020',
      registration: 'SAMPLE',
      description: 'Flat tyre',
      location: 'Nugegoda',
    );
    await tester.pumpWidget(MaterialApp(home: ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();
    expect(find.text('Connect to submit'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    expect((await RequestDraftStore().load())?.registration, 'SAMPLE');
    expect(await RequestDraftStore().submissionId(), isNull);
    connection.changes.add([ConnectivityResult.wifi]);
    await tester.pumpAndSettle();
    expect(
      find.text('Connection restored. Review and submit when ready.'),
      findsOneWidget,
    );
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(await RequestDraftStore().submissionId(), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
