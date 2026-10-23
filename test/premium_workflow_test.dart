import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets(
    'cancellation needs one reason choice and never forces free typing',
    (tester) async {
      String? reason;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  reason = await requestCancellationReason(context);
                },
                child: const Text('Cancel visit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancel visit'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('The provider is taking too long'));
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();
      expect(reason, 'The provider is taking too long');
    },
  );
  testWidgets('custom cancellation requires an explanatory reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => requestCancellationReason(context),
              child: const Text('Cancel visit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cancel visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other reason'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm cancellation'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'short');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm cancellation'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('normal checkout offers real manual payment methods only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => requestCheckout(context, 1900),
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('Demo card'), findsNothing);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'combined request keeps optional choices collapsed in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const BreakdownDetailsScreen(issues: []),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('STEP 1 OF 3'), findsOneWidget);
        expect(find.text('What do you need help with?'), findsOneWidget);
        await tester.tap(find.text('Continue to Location'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose a service or select Not sure.'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('More details (optional)'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Parts preference').hitTestable(), findsNothing);
        await tester.tap(find.text('More details (optional)'));
        await tester.pumpAndSettle();
        expect(find.text('Parts preference'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
