import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'admin role filter works on narrow phone: $brightness / $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 'all';
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(28),
                  child: StatefulBuilder(
                    builder: (context, setState) => AdminUserRoleFilter(
                      selected: selected,
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final role in ['all', 'driver', 'provider', 'all']) {
            await tester.tap(find.byKey(ValueKey('admin-user-role-$role')));
            await tester.pumpAndSettle();
            expect(selected, role);
            expect(
              tester
                  .widget<ChoiceChip>(
                    find.byKey(ValueKey('admin-user-role-$role')),
                  )
                  .selected,
              isTrue,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
