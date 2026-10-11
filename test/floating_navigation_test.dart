import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final dark in [false, true]) {
    for (final provider in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'floating tabs dark=$dark provider=$provider scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final labels = provider
                ? ['Dashboard', 'Requests', 'Jobs', 'Messages', 'Profile']
                : ['Home', 'Requests', 'Messages', 'Profile'];
            var selected = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: StatefulBuilder(
                  builder: (context, update) => Scaffold(
                    body: Text('Selected $selected'),
                    bottomNavigationBar: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        padding: const EdgeInsets.only(bottom: 24),
                      ),
                      child: RaFloatingNavigation(
                        selectedIndex: selected,
                        onSelected: (value) => update(() => selected = value),
                        destinations: [
                          for (final label in labels)
                            NavigationDestination(
                              icon: const Icon(Icons.circle_outlined),
                              label: label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.descendant(
                of: find.byType(RaFloatingNavigation),
                matching: find.byType(BackdropFilter),
              ),
              findsOneWidget,
            );
            final bar = tester.getRect(find.byType(RaFloatingNavigation));
            final firstTab = tester.getRect(find.byType(InkWell).first);
            expect(firstTab.left, greaterThan(bar.left + 16));
            expect(firstTab.bottom, lessThan(800 - 24));
            for (var i = 0; i < labels.length; i++) {
              await tester.tap(find.text(labels[i]));
              await tester.pumpAndSettle();
              expect(find.text('Selected $i'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }
}
