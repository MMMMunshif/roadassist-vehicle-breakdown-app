import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';
import 'package:road_assist/src/services/guest_assistance_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final enabled in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'guest availability $enabled fits narrow large text ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var posts = 0;
          final service = GuestAssistanceService(
            client: MockClient((request) async {
              if (request.method == 'POST') posts++;
              return http.Response('{"enabled":$enabled}', 200);
            }),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildRoadAssistTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: GuestAccessScreen(service: service),
            ),
          );
          await tester.pumpAndSettle();
          if (enabled) {
            await tester.scrollUntilVisible(
              find.text('Continue as guest'),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
          }
          expect(
            find.text('Continue as guest'),
            enabled ? findsOneWidget : findsNothing,
          );
          await tester.scrollUntilVisible(
            find.text('Emergency help'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Emergency help'), findsOneWidget);
          expect(posts, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  test(
    'missing guest service fails closed instead of assuming guest service enabled',
    () async {
      final api = GuestAssistanceService(
        client: MockClient((_) async => http.Response('Not found', 404)),
      );
      expect(await api.available(), false);
      api.dispose();
    },
  );
}
