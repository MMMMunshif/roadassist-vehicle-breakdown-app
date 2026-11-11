import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/widgets/premium_style.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('visit fee estimates match the approved started kilometre tiers', () {
    for (final entry in {
      0.0: 100,
      .8: 100,
      1.0: 100,
      1.001: 120,
      2.0: 120,
      2.2: 140,
    }.entries) {
      expect(estimateProviderVisitFee(entry.key), entry.value);
    }
    expect(estimateProviderVisitFee(null), isNull);
    expect(estimateProviderVisitFee(-1), isNull);
    expect(estimateProviderVisitFee(double.nan), isNull);
    expect(estimateProviderVisitFee(double.infinity), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'fee and details retain form state with large text ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildRoadAssistTheme(brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      const ProviderVisitFeeEstimate(distanceKm: 2.2),
                      RaDetailsDisclosure(
                        storageKey: 'form-test',
                        title: 'Job details',
                        child: TextField(controller: controller),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Estimated visit fee · Rs. 140'), findsOneWidget);
        expect(find.byType(TextField).hitTestable(), findsNothing);
        await tester.tap(find.text('Job details'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Keep these work notes');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.tap(find.text('Job details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Job details'));
        await tester.pumpAndSettle();
        expect(controller.text, 'Keep these work notes');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'tab motion preserves child state on switching and reduced motion',
    (tester) async {
      var index = 0;
      var reduce = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reduce),
                  child: RaMemberTabStack(
                    index: index,
                    children: const [_Counter(), Text('Other tab')],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      update(() => index = 1);
      await tester.pumpAndSettle();
      expect(find.text('Other tab'), findsOneWidget);
      expect(find.text('Count 1'), findsNothing);
      update(() => index = 0);
      await tester.pumpAndSettle();
      expect(find.text('Count 1'), findsOneWidget);
      update(() => reduce = true);
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      update(() => index = 1);
      await tester.pump();
      update(() => index = 0);
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('Count $value'),
  );
}
