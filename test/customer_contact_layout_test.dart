import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  for (final width in [320.0, 430.0, 1000.0]) {
    testWidgets('customer contact layout and mouse hover at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CustomerContactScreen(
        requestId: 'contact-layout-test',
        requestData: {'driverName': 'Test Driver', 'driverPhone': '0771234567', 'status': 'arrived', 'modelYear': 'Toyota Aqua 2018', 'registration': 'WP CAB-1234'},
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Call Customer')));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Send Message')));
      await tester.pump();
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }
}
