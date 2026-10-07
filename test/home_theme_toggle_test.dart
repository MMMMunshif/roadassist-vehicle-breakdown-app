import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home switches themes both ways and restores saved choice', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppThemeController.mode.value = ThemeMode.light;
    addTearDown(() => AppThemeController.mode.value = ThemeMode.system);
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, child) => MaterialApp(
        theme: buildRoadAssistTheme(Brightness.light),
        darkTheme: buildRoadAssistTheme(Brightness.dark),
        themeMode: mode,
        home: const Scaffold(body: DriverHomeScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    final toggle = find.byTooltip('Dark mode');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(toggle)).brightness, Brightness.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('roadassist_theme_mode'), 'dark');
    AppThemeController.mode.value = ThemeMode.system;
    await AppThemeController.initialize();
    await tester.pumpAndSettle();
    expect(AppThemeController.mode.value, ThemeMode.dark);
    await tester.tap(find.byTooltip('Light mode'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(toggle)).brightness, Brightness.light);
    expect(preferences.getString('roadassist_theme_mode'), 'light');
    expect(tester.takeException(), isNull);
  });
}
