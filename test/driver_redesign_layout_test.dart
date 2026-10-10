import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/service_invoice.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  final pages = <String, Widget Function()>{
    'assistance': () => const AssistanceTypeScreen(),
    'breakdown': () => const BreakdownDetailsScreen(issues: ['Flat Tyre']),
    'vehicle': () => const VehicleEditorScreen(),
    'GPS recovery': () => const GpsIssueScreen(),
    'request details': () => const DriverRequestDetailsScreen(),
    'history': () => const HistoryScreen(),
    'vehicles': () => const VehiclesScreen(),
  };
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in pages.entries) {
        testWidgets('${entry.key} at 320/$scale/${brightness.name}', (
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
              home: RaDriverTheme(child: entry.value()),
            ),
          );
          await tester.pumpAndSettle();
          final failure = tester.takeException();

          expect(failure, isNull);
          if (entry.key == 'assistance') {
            await tester.scrollUntilVisible(find.text('Flat Tyre'), 200);
            await Scrollable.ensureVisible(
              tester.element(find.text('Flat Tyre')),
              alignment: .3,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Flat Tyre'));
            await tester.pumpAndSettle();
            expect(find.text('1 issue selected'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var i = 0; i < 7; i++) {
              await tester.drag(scrollables.first, const Offset(0, -450));
              await tester.pumpAndSettle();
              final failure = tester.takeException();

              expect(failure, isNull);
            }
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('Driver bill exposes working download and share actions', (
    tester,
  ) async {
    var downloads = 0;
    var shares = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoadAssistTheme(Brightness.light),
        home: RaDriverScaffold(
          body: SingleChildScrollView(
            child: InvoiceBillView(
              invoice: ServiceInvoice.fromRequest('job', {
                'status': 'completed',
                'finalCost': 4500,
                'driverName': 'Driver',
                'providerName': 'Provider',
              }),
              onDownload: () => downloads++,
              onShare: () => shares++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Download PDF'), 250);
    await tester.tap(find.text('Download PDF'));
    await tester.ensureVisible(find.text('Share PDF'));
    await tester.tap(find.text('Share PDF'));
    expect(downloads, 1);
    expect(shares, 1);
    expect(tester.takeException(), isNull);
  });
}
