import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 600.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final arrived in [false, true]) {
          testWidgets(
            'Active job $arrived at $width/$scale/${brightness.name}',
            (tester) async {
              tester.view.physicalSize = Size(width, 900);
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
                  home: ProviderActiveJobScreen(
                    requestData: {
                      'driverName': 'A driver with a long display name',
                      'driverPhone': '0771234567',
                      'status': arrived ? 'arrived' : 'en_route',
                      'modelYear': 'Toyota Aqua 2018',
                      'registration': 'WP CAB-1234',
                      'locationLabel':
                          'A long address near Nugegoda, Colombo, Sri Lanka',
                      'issues': ['Flat Tyre'],
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.byTooltip('Message driver'), findsNothing);
              if (arrived) {
                await tester.scrollUntilVisible(
                  find.text('Service notes'),
                  250,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.pumpAndSettle();
                await tester.enterText(
                  find.byType(TextField).first,
                  'Tyre replaced and pressure checked.',
                );
                await tester.pump();
              } else {
                await tester.scrollUntilVisible(
                  find.text('Message'),
                  200,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
        testWidgets(
          'Summary and revenue wrap at $width/$scale/${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
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
                home: RaProviderScaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      RaProviderSummaryCard(
                        title: 'Waiting for driver confirmation',
                        message:
                            'Your service documentation has been submitted for the driver to review.',
                        icon: Icons.task_alt,
                        status: Text('Pending driver confirmation'),
                      ),
                      SizedBox(height: 16),
                      RaProviderMetricGrid(
                        metrics: {
                          'Completed jobs': '999',
                          'Cancelled jobs': '12',
                          'Total revenue': 'Rs. 999,999,999',
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(find.text('Rs. 999,999,999'), 200);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Provider typography follows shared route and leaves driver theme unchanged',
    (tester) async {
      Widget destination() => RaScaffold(
        body: Builder(
          builder: (context) => Text(
            'Shared settings',
            style: TextStyle(fontSize: providerFontSize(context, 9)),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RaProviderScaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => push(context, destination()),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Shared settings')).style!.fontSize,
        12,
      );
      await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: destination()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Shared settings')).style!.fontSize,
        9,
      );
    },
  );
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      for (final width in [320.0, 390.0]) {
        testWidgets(
          'Provider shared pages at $width/$scale/${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            for (final page in const <Widget>[
              AppearanceScreen(),
              NotificationSettingsScreen(),
              PrivacySafetyScreen(isProvider: true),
              SupportScreen(isProvider: true),
            ]) {
              await tester.pumpWidget(
                MaterialApp(
                  key: UniqueKey(),
                  theme: buildRoadAssistTheme(brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RaProviderTheme(child: page),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType} initial layout',
              );
              for (var i = 0; i < 4; i++) {
                await tester.drag(
                  find.byType(Scrollable).first,
                  const Offset(0, -500),
                );
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${page.runtimeType} scrolled layout',
                );
              }
            }
          },
        );
      }
    }
  }
}
