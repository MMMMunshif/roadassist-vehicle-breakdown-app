import 'dart:async';
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
    testWidgets('render native splash and Welcome handoff ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('PlusJakartaSans');
        for (final weight in [
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
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final key = GlobalKey();
      final ready = Completer<Widget>();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildRoadAssistTheme(brightness),
            home: SplashScreen(destinationLoader: () => ready.future),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final image in [
          'auth_journey_car.png',
          'roadassist_mark.png',
          'roadassist_logo.png',
          'welcome_background.png',
          'welcome_background_light.png',
        ]) {
          await precacheImage(
            AssetImage('assets/images/$image'),
            key.currentContext!,
          );
        }
      });
      Future<void> capture(String name) async {
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File(
            'build/previews/splash-implementation/$name-${brightness.name}.png',
          );
          await f.parent.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pump(const Duration(milliseconds: 2800));
      await capture('handshake');
      await tester.pump(const Duration(milliseconds: 1500));
      await capture('splash-ready');
      ready.complete(const WelcomeScreen());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await capture('handoff');
      await tester.pumpAndSettle();
      await capture('welcome');
    });
  }
}
