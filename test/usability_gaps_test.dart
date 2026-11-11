import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:road_assist/src/screens.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('receipt reminder only follows an unconfirmed real payment report', () {
    final pending = <String, dynamic>{
      'status': 'completed',
      'driverReportedPayment': true,
      'paymentMethod': 'cash',
    };
    expect(needsProviderReceiptConfirmation(pending), isTrue);
    expect(
      needsProviderReceiptConfirmation({
        ...pending,
        'providerConfirmedPayment': true,
      }),
      isFalse,
    );
    expect(
      needsProviderReceiptConfirmation({
        ...pending,
        'driverReportedPayment': false,
      }),
      isFalse,
    );
    expect(
      needsProviderReceiptConfirmation({...pending, 'status': 'cancelled'}),
      isFalse,
    );
    expect(
      needsProviderReceiptConfirmation({
        ...pending,
        'paymentMethod': 'demo_card',
      }),
      isFalse,
    );
    expect(
      needsProviderReceiptConfirmation({
        ...pending,
        'demoPayment': {'status': 'simulated'},
      }),
      isFalse,
    );
    expect(needsProviderReceiptConfirmation({}), isFalse);
  });
  testWidgets(
    'normal checkout hides card demo and requires an explicit cash choice',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await requestCheckout(
                    context,
                    1900,
                    showDemoCard: false,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Pay by card'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Choose payment method'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm cash paid'));
      await tester.pumpAndSettle();
      expect(result, 'cash');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved server data is disclosed without claiming a live connection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestSyncStatus(
              showingSavedData: true,
              lastSynced: DateTime(2026, 10, 24, 12, 30),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Showing saved request details.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last server update:'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RequestSyncStatus(showingSavedData: false)),
        ),
      );
      expect(find.byType(InlineMessage), findsNothing);
    },
  );
  testWidgets('cancellation explains fee and refund before confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => requestCancellationReason(context),
              child: const Text('Open cancel'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No cancellation fee is added'), findsOneWidget);
    expect(find.textContaining('not automatically refunded'), findsOneWidget);
  });
}
