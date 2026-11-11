import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/models/service_invoice.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('render redesigned native screens ${brightness.name}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
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
      Future<void> render(Widget page) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildRoadAssistTheme(brightness),
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/previews/redesign-final/$name-${brightness.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await render(
        const ProviderActiveJobScreen(
          requestData: {
            'status': 'arrived',
            'driverName': 'Nimal Perera',
            'driverPhone': '0771234567',
            'modelYear': 'Toyota Aqua 2018',
            'registration': 'CAB-1234',
            'issues': ['General Mechanic'],
            'locationLabel': 'Galle Road, Colombo',
            'estimatedCost': 100,
          },
        ),
      );
      await capture('provider-job');
      await render(
        RaDriverScaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: InvoiceBillView(
              invoice: ServiceInvoice.fromRequest('preview-job', {
                'status': 'completed',
                'finalCost': 1900,
                'estimatedCost': 100,
                'providerName': 'Ravi Perera',
                'driverName': 'Nimal Perera',
                'issues': ['General Mechanic'],
                'serviceNotes': 'Repaired the loose terminal connection.',
              }),
            ),
          ),
        ),
      );
      await capture('invoice');
      await render(const AppearanceScreen());
      await capture('appearance');
      await render(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  requestCheckout(context, 1900, showDemoCard: true),
              child: const Text('Open checkout'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await capture('cash');
      await tester.tap(find.text('Pay by card'));
      await tester.pumpAndSettle();
      await capture('card');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
