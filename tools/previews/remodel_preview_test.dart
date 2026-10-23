import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/request_draft.dart';

// Run explicitly: flutter test tools/previews/remodel_preview_test.dart.
void main() {
  for (final brightness in Brightness.values) {
    for (final provider in [false, true]) {
      testWidgets(
        'render ${provider ? 'provider' : 'driver'} ${brightness.name}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          GoogleFonts.config.allowRuntimeFetching = false;
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            final localFonts = FontLoader('PlusJakartaSans');
            for (final weight in [
              'ExtraLight',
              'Light',
              'Regular',
              'Medium',
              'SemiBold',
              'Bold',
              'ExtraBold',
            ]) {
              localFonts.addFont(
                rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
              );
            }
            await localFonts.load();
            await (FontLoader('Manrope')..addFont(
                  rootBundle.load('assets/fonts/Manrope-Variable.ttf'),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          final key = GlobalKey();
          final bill = {
            'dispatchFee': 100,
            'inspectionFee': 300,
            'serviceFee': 1500,
          };
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildRoadAssistTheme(brightness),
                home: provider
                    ? RaProviderScaffold(
                        appBar: AppBar(title: const Text('Active assistance')),
                        body: Builder(
                          builder: (context) => Center(
                            child: FilledButton(
                              onPressed: () => requestFinalBill(context, bill),
                              child: const Text('Finish service'),
                            ),
                          ),
                        ),
                      )
                    : BreakdownDetailsScreen(
                        issues: ['Flat Tyre'],
                        initialDraft: RequestDraft(
                          issues: ['Flat Tyre'],
                          vehicleId: 'preview-vehicle',
                          vehicleType: 'Sedan / Hatchback',
                          modelYear: 'Toyota Aqua 2018',
                          registration: 'CAB-1234',
                          description: 'Rear tyre is punctured.',
                        ),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (provider) {
            await tester.tap(find.text('Finish service'));
            await tester.pumpAndSettle();
          }
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/previews/${provider ? 'provider-bill' : 'driver-request'}-${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
