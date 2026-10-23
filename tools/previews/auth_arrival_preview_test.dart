import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final mode in ['login', 'driver', 'provider']) {
      testWidgets('render actual auth ${brightness.name} mode=$mode', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final font = FontLoader('PlusJakartaSans');
          for (final weight in [
            'ExtraLight',
            'Light',
            'Regular',
            'Medium',
            'SemiBold',
            'Bold',
            'ExtraBold',
          ]) {
            font.addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
            );
          }
          await font.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildRoadAssistTheme(brightness),
              home: mode == 'login'
                  ? const LoginScreen()
                  : RegistrationScreen(isProvider: mode == 'provider'),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final asset in [
            'auth_journey_car.png',
            'roadassist_mark.png',
            'roadassist_logo.png',
            'google_g.png',
          ]) {
            await precacheImage(
              AssetImage('assets/images/$asset'),
              key.currentContext!,
            );
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File(
            'build/previews/auth-arrival-${mode}-${brightness.name}.png',
          );
          await f.parent.create(recursive: true);
          await f.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
