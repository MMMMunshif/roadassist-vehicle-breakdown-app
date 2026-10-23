import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/app.dart';
import 'package:road_assist/src/screens.dart';

// Isolated design exploration. All account, location and request data are samples.
void main() {
  for (final dark in [false, true]) {
    for (final provider in [false, true]) {
      testWidgets('premium ${provider ? "provider" : "driver"} $dark', (tester) async {
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final loader = FontLoader('PlusJakartaSans');
          for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
            loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'));
          }
          await loader.load();
          await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        });
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildRoadAssistTheme(dark ? Brightness.dark : Brightness.light),
          home: PremiumConcept(provider: provider, dark: dark),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final bitmap = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/premium-${provider ? "provider" : "driver"}-${dark ? "dark" : "light"}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      });
    }
  }
}

class PremiumConcept extends StatelessWidget {
  const PremiumConcept({super.key, required this.provider, required this.dark});
  final bool provider, dark;
  Color get ink => dark ? const Color(0xfff0f5ff) : const Color(0xff122d45);
  Color get muted => dark ? const Color(0xffa6bbce) : const Color(0xff5c7388);
  static const blue = Color(0xff1689ff);
  Widget text(String value, double size, {Color? color, FontWeight weight = FontWeight.w500}) => Text(value, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, height: 1.4, color: color ?? ink, fontWeight: weight));
  Widget gap(double h) => SizedBox(height: h);
  Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
    width: double.infinity, padding: padding,
    decoration: BoxDecoration(color: dark ? const Color(0xff102a40).withValues(alpha: .89) : Colors.white.withValues(alpha: .88), borderRadius: BorderRadius.circular(24), border: Border.all(color: dark ? Colors.white.withValues(alpha: .10) : const Color(0xffdbe8f2))), child: child);
  Widget iconBox(IconData icon, {Color color = blue}) => Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 23));
  Widget pill(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(30)), child: text(label, 10, color: color, weight: FontWeight.w800));
  Widget heading(String title, String action) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [text(title, 17, weight: FontWeight.w800), text(action, 11, color: dark ? const Color(0xff91c8ff) : const Color(0xff0865bd), weight: FontWeight.w700)]);
  Widget primary(String label, {bool white = false}) => Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: white ? Colors.white : blue, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [text(label, 13, color: white ? const Color(0xff075ba9) : Colors.white, weight: FontWeight.w800), const SizedBox(width: 10), Icon(Icons.arrow_forward_rounded, size: 18, color: white ? const Color(0xff075ba9) : Colors.white)]));
  @override
  Widget build(BuildContext context) => RaScaffold(
    body: SafeArea(child: Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 105), children: [
        Row(children: [Image.asset('assets/images/roadassist_logo.png', width: 35, height: 35), const SizedBox(width: 9), text('RoadAssist', 21, weight: FontWeight.w800), const Spacer(), Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: muted.withValues(alpha: .25))), child: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: muted, size: 19)), const SizedBox(width: 9), Stack(children: [iconBox(Icons.notifications_none_rounded), Positioned(right: 10, top: 9, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: blue, shape: BoxShape.circle)))])]),
        gap(25),
        text(provider ? 'YOUR WORKSPACE' : 'HERE FOR EVERY MILE', 9, color: muted, weight: FontWeight.w800),
        gap(5), text(provider ? 'Ready when you are.' : 'A little help.\nA smoother journey.', 29, weight: FontWeight.w800),
        gap(9), Row(children: [Icon(provider ? Icons.verified_outlined : Icons.location_on_outlined, size: 15, color: blue), const SizedBox(width: 5), text(provider ? 'Verified provider  ·  Colombo' : 'Colombo, Sri Lanka', 11, color: muted), const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 16)]),
        gap(23),
        if (!provider) ...driver() else ...workspace(),
        gap(18), Row(children: [Icon(Icons.shield_outlined, size: 15, color: muted), const SizedBox(width: 7), Expanded(child: text(provider ? 'Clear charges. Approve extra work before starting.' : 'Verified providers. Clear fees. Help you can trust.', 10, color: muted))]),
      ]),
      Positioned(bottom: 14, left: 16, right: 16, child: ClipRRect(borderRadius: BorderRadius.circular(29), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(height: 77, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8), decoration: BoxDecoration(color: (dark ? const Color(0xff173247) : Colors.white).withValues(alpha: .76), borderRadius: BorderRadius.circular(29), border: Border.all(color: (dark ? Colors.white : blue).withValues(alpha: .16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [nav(provider ? Icons.dashboard_rounded : Icons.home_rounded, provider ? 'Overview' : 'Home', true), nav(Icons.receipt_long_outlined, 'Requests', false), if(provider) nav(Icons.work_outline_rounded, 'Jobs', false), nav(Icons.chat_bubble_outline_rounded, 'Messages', false), nav(Icons.person_outline_rounded, 'Profile', false)]))))),
    ])),
  );
  Widget nav(IconData icon, String label, bool active) => Container(width: provider ? 65 : 76, decoration: BoxDecoration(color: active ? blue : Colors.transparent, borderRadius: BorderRadius.circular(21)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: active ? Colors.white : muted, size: 22), const SizedBox(height: 4), text(label, 8, color: active ? Colors.white : muted, weight: active ? FontWeight.w800 : FontWeight.w600)]));
  List<Widget> driver() => [
    Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff0966d1), Color(0xff00a4c4)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(27)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.car_repair_rounded, size: 30, color: Colors.white), const Spacer(), pill('24/7 ASSISTANCE', Colors.white)]), gap(15), text('Back on the road,\nwithout the worry.', 23, color: Colors.white, weight: FontWeight.w800), gap(7), text('Tell us what happened. We will help\nyou find the right nearby provider.', 11, color: Colors.white.withValues(alpha: .85)), gap(18), primary('Request help', white: true)])),
    gap(22), heading('Your vehicle', 'Manage'), gap(10),
    panel(Row(children: [iconBox(Icons.directions_car_filled_outlined), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text('Toyota Aqua', 14, weight: FontWeight.w800), gap(3), text('CAB-1234  ·  2018  ·  Hybrid', 10, color: muted)])), Icon(Icons.chevron_right_rounded, color: muted)])),
    gap(21), heading('Help for every setback', 'View all'), gap(11),
    Row(children: [Expanded(child: service(Icons.build_outlined, 'Mechanic')), const SizedBox(width: 9), Expanded(child: service(Icons.tire_repair_outlined, 'Flat tyre')), const SizedBox(width: 9), Expanded(child: service(Icons.battery_charging_full_rounded, 'Battery'))]),
  ];
  Widget service(IconData icon, String label) => panel(Column(children: [Icon(icon, color: dark ? const Color(0xff91c8ff) : blue, size: 23), gap(9), text(label, 10, weight: FontWeight.w700)]), padding: const EdgeInsets.symmetric(vertical: 16));
  List<Widget> workspace() => [
    panel(Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xff36d7a0), shape: BoxShape.circle)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text('You are online', 14, weight: FontWeight.w800), text('Nearby drivers can request your help', 10, color: muted)])), Container(width: 47, height: 28, alignment: Alignment.centerRight, padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: const Color(0xff19b986), borderRadius: BorderRadius.circular(30)), child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))])),
    gap(19), heading('Today at a glance', 'View earnings'), gap(10),
    Row(children: [Expanded(child: metric('LKR 4,000', 'Collected today', Icons.account_balance_wallet_outlined)), const SizedBox(width: 10), Expanded(child: metric('3 jobs', 'Completed today', Icons.task_alt_rounded))]),
    gap(21), heading('New request', '1 nearby'), gap(10),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [iconBox(Icons.build_outlined), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text('General mechanic', 15, weight: FontWeight.w800), text('Toyota Aqua  ·  CAB-1234', 10, color: muted)])), pill('NEW', dark ? const Color(0xff6ae6bf) : const Color(0xff00805b))]), gap(16), Row(children: [Icon(Icons.near_me_outlined, color: blue, size: 16), const SizedBox(width: 7), text('1.8 km away', 11), const Spacer(), text('Visit fee', 10, color: muted), const SizedBox(width: 7), text('Rs. 120', 13, weight: FontWeight.w800)]), gap(11), text('Engine will not start. Parked near the\nmain entrance of the supermarket.', 11, color: muted), gap(17), primary('View request'), gap(9), Center(child: text('Inspection & repairs billed after the work', 9, color: muted))])),
  ];
  Widget metric(String amount, String label, IconData icon) => panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: blue, size: 20), gap(11), text(amount, 18, weight: FontWeight.w800), gap(3), text(label, 9, color: muted)]), padding: const EdgeInsets.all(16));
}
