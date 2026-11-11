from pathlib import Path
p=Path('test/completion_report_test.dart');s=p.read_text(encoding='utf-8');a=s.index("        expect(find.text('Final total: Rs. 1,800')");b=s.index('        await tester.pumpAndSettle();',s.index("await tester.tap(find.text('Cancel'));",a))+len('        await tester.pumpAndSettle();');s=s[:a]+'''        expect(find.text('LKR 1,800.00'), findsOneWidget);
        expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Choose payment method')).onPressed, isNull);
        await tester.tap(find.text('Pay by card'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Try demo checkout'));
        await tester.pumpAndSettle();
        expect(find.text('SANDBOX / NO REAL CHARGE'), findsOneWidget);
        await tester.tap(find.text('Back to payment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm cash paid'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close payment'));
        await tester.pumpAndSettle();'''+s[b:];p.write_text(s,encoding='utf-8')
p=Path('test/premium_workflow_test.dart');s=p.read_text(encoding='utf-8').replace('normal checkout offers real manual payment methods only','checkout offers cash and clearly labelled card demo').replace("expect(find.text('Bank transfer'), findsOneWidget);","expect(find.text('Bank transfer'), findsNothing);\n    expect(find.text('Pay by card'), findsOneWidget);\n    await tester.tap(find.text('Pay by card'));\n    await tester.pumpAndSettle();\n    expect(find.text('Secure card checkout · Demo'), findsOneWidget);");p.write_text(s,encoding='utf-8')
