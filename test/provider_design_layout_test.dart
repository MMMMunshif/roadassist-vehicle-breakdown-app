import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 600.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('Provider cards fit $width at $scale in ${brightness.name}', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var viewed = false;
          var online = false;
          var edited = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildRoadAssistTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: StatefulBuilder(
                builder: (context, update) => RaScaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      RaProviderHeader(
                        notifications: IconButton(
                          tooltip: 'New requests',
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RaProviderIdentityCard(
                        avatar: const CircleAvatar(child: Text('H')),
                        speciality: 'General Mechanic +2 additional services',
                        online: online,
                        status: online ? 'Online' : 'Currently offline',
                        onChanged: (value) => update(() => online = value),
                        onRefreshLocation: () {},
                      ),
                      const SizedBox(height: 16),
                      RaProviderRequestTile(
                        driver: 'Nimal Perera with a longer display name',
                        issue: 'Flat tyre and roadside assistance',
                        location:
                            'A long road address in Nugegoda, Colombo, Sri Lanka',
                        distance: '2.4 km away',
                        time: '2 min ago',
                        priority: 'Urgent',
                        onView: () => viewed = true,
                        onDismiss: () {},
                      ),
                      const SizedBox(height: 16),
                      RaProviderCard(
                        child: Column(
                          children: [
                            RaProviderSettingRow(
                              icon: Icons.schedule_outlined,
                              label: 'Working hours',
                              value: 'Daily, 8 AM–8 PM',
                              onTap: () => edited = true,
                            ),
                            const Divider(height: 1),
                            RaProviderSettingRow(
                              icon: Icons.power_settings_new_rounded,
                              label: 'Accepting requests',
                              trailing: Switch(
                                value: online,
                                onChanged: (value) =>
                                    update(() => online = value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Messages'), findsNothing);
          await tester.tap(find.byType(Switch).first);
          await tester.pumpAndSettle();
          expect(online, isTrue);
          await tester.scrollUntilVisible(find.text('View request'), 200);
          await tester.pumpAndSettle();
          await tester.tap(find.text('View request'));
          expect(viewed, isTrue);
          await tester.scrollUntilVisible(find.text('Working hours'), 200);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Working hours'));
          expect(edited, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('stale provider location can be refreshed from the dashboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RaProviderIdentityCard(
              avatar: const CircleAvatar(child: Text('H')),
              speciality: 'General Mechanic',
              online: true,
              status: 'Online · location needed',
              onChanged: (_) {},
              onRefreshLocation: () => refreshed = true,
              locationNeedsRefresh: true,
              locationMessage:
                  'Turn on phone location and allow RoadAssist location permission.',
            ),
          ),
        ),
      );

      expect(find.text('Online · location needed'), findsOneWidget);
      expect(find.textContaining('Turn on phone location'), findsOneWidget);
      await tester.tap(find.text('Update location'));
      expect(refreshed, isTrue);
    });
  }
}
