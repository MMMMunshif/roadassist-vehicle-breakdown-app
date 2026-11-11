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
          final file = File('build/previews/advanced-${provider ? "provider" : "driver"}-${dark ? "dark" : "light"}.png');
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
  Color get ink => dark ? const Color(0xffecf5ff) : const Color(0xff102d46);
  Color get muted => dark ? const Color(0xff99b1c5) : const Color(0xff60788c);
  Color get blue => dark ? const Color(0xff71bcff) : const Color(0xff0075d8);
  Color get surface => dark ? const Color(0xff102a3f) : Colors.white;
  Widget t(String s,double size,{Color? c,FontWeight w=FontWeight.w500}) => Text(s,style:TextStyle(fontFamily:'PlusJakartaSans',fontSize:size,height:1.25,color:c??ink,fontWeight:w));
  Widget g(double x)=>SizedBox(height:x);
  Widget tag(String s,{Color? c})=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:(c??blue).withValues(alpha:.12),borderRadius:BorderRadius.circular(30),border:Border.all(color:(c??blue).withValues(alpha:.20))),child:t(s,9,c:c??blue,w:FontWeight.w800));
  Widget card(Widget child,{EdgeInsets? padding,Color? color,double radius=24})=>Container(padding:padding??const EdgeInsets.all(18),decoration:BoxDecoration(color:color??surface.withValues(alpha:.83),borderRadius:BorderRadius.circular(radius),border:Border.all(color:(dark?Colors.white:blue).withValues(alpha:.13))),child:child);
  Widget circle(IconData i)=>Container(width:38,height:38,decoration:BoxDecoration(color:surface.withValues(alpha:.7),shape:BoxShape.circle,border:Border.all(color:blue.withValues(alpha:.18))),child:Icon(i,size:19,color:ink));
  Widget action(String s)=>Container(height:52,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff168fff),Color(0xff0565ee)]),borderRadius:BorderRadius.circular(17),boxShadow:[BoxShadow(color:const Color(0xff077bff).withValues(alpha:.20),blurRadius:22,offset:const Offset(0,7))]),padding:const EdgeInsets.symmetric(horizontal:18),child:Row(children:[t(s,14,c:Colors.white,w:FontWeight.w800),const Spacer(),Container(width:29,height:29,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.17),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.north_east_rounded,color:Colors.white,size:19))]));
  @override
  Widget build(BuildContext context)=>RaScaffold(body:SafeArea(child:Stack(children:[
    ListView(padding:const EdgeInsets.fromLTRB(22,18,22,105),children:[
      Row(children:[Image.asset('assets/images/roadassist_mark.png',width:33,height:37),const SizedBox(width:8),t('RoadAssist',20,w:FontWeight.w800),const Spacer(),circle(dark?Icons.dark_mode_outlined:Icons.light_mode_outlined),const SizedBox(width:9),circle(Icons.notifications_none_rounded)]),
      g(23),Row(children:[t(provider?'PARTNER WORKSPACE':'YOUR JOURNEY, PROTECTED',9,c:muted,w:FontWeight.w800),const Spacer(),tag(provider?'VERIFIED':'DRIVER')]),
      g(9),t(provider?'Your next move.':'Every road.\nWe are with you.',32,w:FontWeight.w800),g(11),
      Row(children:[Icon(Icons.location_on_outlined,color:blue,size:14),const SizedBox(width:5),t('Colombo, Sri Lanka',11,c:muted),const SizedBox(width:5),Icon(Icons.expand_more_rounded,color:muted,size:15),const Spacer(),if(!provider)t('Change',10,c:blue,w:FontWeight.w700)]),
      g(21), if(provider)...partner() else ...driver(),
    ]),
    Positioned(bottom:16,left:20,right:20,child:ClipRRect(borderRadius:BorderRadius.circular(28),child:BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:22,sigmaY:22),child:Container(height:73,padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:(dark?const Color(0xff183347):Colors.white).withValues(alpha:.78),borderRadius:BorderRadius.circular(28),border:Border.all(color:(dark?Colors.white:blue).withValues(alpha:.2))),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[nav(Icons.grid_view_rounded,provider?'Workspace':'Home',true),nav(Icons.receipt_long_outlined,'Requests',false),if(provider)nav(Icons.work_outline_rounded,'Jobs',false),nav(Icons.forum_outlined,'Messages',false),nav(Icons.person_outline_rounded,'You',false)]))))),
  ])));
  Widget nav(IconData i,String s,bool selected)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:selected?blue.withValues(alpha:.16):Colors.transparent,borderRadius:BorderRadius.circular(19)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(i,color:selected?blue:muted,size:21),g(4),t(s,8,c:selected?blue:muted,w:selected?FontWeight.w800:FontWeight.w600)]));
  Widget heading(String a,String b)=>Row(children:[t(a,17,w:FontWeight.w800),const Spacer(),t(b,10,c:blue,w:FontWeight.w700)]);
  List<Widget> driver()=>[
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[tag('YOUR GARAGE'),const Spacer(),Icon(Icons.more_horiz,color:muted,size:22)]),g(10),
      Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Toyota Aqua',23,w:FontWeight.w800),g(4),t('CAB-1234  /  HYBRID',9,c:muted,w:FontWeight.w700)])),tag('DEFAULT')]),
      SizedBox(height:139,child:Stack(children:[Positioned.fill(child:CustomPaint(painter:VehicleArt(dark:dark))),Positioned(left:0,bottom:10,child:tag('2018')),Positioned(right:0,bottom:10,child:Row(children:[Icon(Icons.shield_outlined,size:13,color:blue),const SizedBox(width:4),t('Ready for the road',9,c:muted)]))])),
      Container(height:1,color:blue.withValues(alpha:.12)),g(15),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('A setback? We have you.',14,w:FontWeight.w800),g(4),t('Get the right help in a few taps.',10,c:muted)])),Icon(Icons.car_repair_rounded,color:blue,size:28)]),g(16),action('Find roadside help'),
    ]),radius:28),
    g(21),heading('What do you need?','Explore'),g(12),
    Row(children:[Expanded(child:tile(Icons.build_outlined,'Mechanic','Engine & repairs')),const SizedBox(width:10),Expanded(child:tile(Icons.tire_repair_outlined,'Flat tyre','Repair & replace'))]),g(10),
    Row(children:[Expanded(child:mini(Icons.battery_charging_full_rounded,'Battery')),const SizedBox(width:10),Expanded(child:mini(Icons.local_shipping_outlined,'Towing'))]),
    g(17),Row(children:[Icon(Icons.verified_user_outlined,size:15,color:blue),const SizedBox(width:7),t('Verified help',10,c:muted),const Spacer(),Icon(Icons.receipt_long_outlined,size:15,color:blue),const SizedBox(width:7),t('Clear, itemised bills',10,c:muted)]),
  ];
  Widget tile(IconData i,String a,String b)=>card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(i,color:blue,size:25),const Spacer(),Icon(Icons.north_east_rounded,color:muted,size:15)]),g(15),t(a,13,w:FontWeight.w800),g(3),t(b,9,c:muted)]),padding:const EdgeInsets.all(15),radius:21);
  Widget mini(IconData i,String s)=>card(Row(children:[Icon(i,size:20,color:blue),const SizedBox(width:9),t(s,11,w:FontWeight.w700),const Spacer(),Icon(Icons.chevron_right_rounded,color:muted,size:16)]),padding:const EdgeInsets.all(14),radius:19);
  List<Widget> partner()=>[
    card(Row(children:[Container(width:9,height:9,decoration:const BoxDecoration(color:Color(0xff39dbae),shape:BoxShape.circle)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Online & ready',14,w:FontWeight.w800),g(3),t('You are visible to nearby drivers',10,c:muted)])),Container(width:46,height:27,alignment:Alignment.centerRight,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xff23bd93),borderRadius:BorderRadius.circular(20)),child:const CircleAvatar(radius:10.5,backgroundColor:Colors.white))]),radius:22),
    g(12),Row(children:[Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[t('COLLECTED TODAY',8,c:muted,w:FontWeight.w800),const Spacer(),Icon(Icons.north_east_rounded,color:blue,size:14)]),g(9),t('Rs. 4,000',23,w:FontWeight.w800),g(4),t('3 completed jobs',10,c:muted)]),padding:const EdgeInsets.all(16))),const SizedBox(width:10),SizedBox(width:112,child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.star_rounded,color:const Color(0xffffba53),size:19),g(6),t('4.9',23,w:FontWeight.w800),g(4),t('Driver rating',9,c:muted)]),padding:const EdgeInsets.all(15)))]),
    g(22),heading('Your next opportunity','1 NEW'),g(12),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[tag('DIRECT REQUEST',c:dark?const Color(0xff6ce6bd):const Color(0xff008760)),const Spacer(),Icon(Icons.bolt_rounded,color:blue,size:16),t('Just now',9,c:muted)]),g(17),t('Engine will not start',21,w:FontWeight.w800),g(6),t('General mechanic  /  Toyota Aqua',11,c:muted),g(18),
      Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:blue.withValues(alpha:.12),borderRadius:BorderRadius.circular(14)),alignment:Alignment.center,child:t('AA',12,c:blue,w:FontWeight.w800)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Ahamed Affan',12,w:FontWeight.w800),g(3),t('Colombo 07',10,c:muted)])),Icon(Icons.near_me_outlined,color:blue,size:15),const SizedBox(width:5),t('1.8 km',11,w:FontWeight.w800)]),
      g(17),Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:blue.withValues(alpha:.07),borderRadius:BorderRadius.circular(16)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('AUTOMATIC VISIT FEE',8,c:muted,w:FontWeight.w800),g(4),t('Inspection & repairs billed later',9,c:muted)])),t('Rs. 120',20,w:FontWeight.w800)])),g(17),action('View & accept request'),
    ]),radius:27),
    g(16),Row(children:[Icon(Icons.history_rounded,color:blue,size:17),const SizedBox(width:8),t('Jobs & payment follow-ups',11,w:FontWeight.w700),const Spacer(),Icon(Icons.arrow_forward_rounded,color:muted,size:17)]),
  ];
}

class VehicleArt extends CustomPainter {
  VehicleArt({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas,Size s){
    final blue=const Color(0xff3ba4ff);
    final center=Offset(s.width*.53,s.height*.60);
    for(final scale in [1.0,.78,.55]){
      canvas.drawOval(Rect.fromCenter(center:center,width:s.width*.91*scale,height:s.height*.76*scale),Paint()..color=blue.withValues(alpha:.10)..style=PaintingStyle.stroke..strokeWidth=1);
    }
    canvas.drawOval(Rect.fromCenter(center:Offset(s.width*.50,s.height*.80),width:s.width*.72,height:15),Paint()..color=blue.withValues(alpha:.15)..maskFilter=const MaskFilter.blur(BlurStyle.normal,9));
    canvas.save();canvas.translate(s.width*.10,s.height*.21);canvas.scale(s.width/350,s.height/160);
    final body=Path()..moveTo(15,85)..quadraticBezierTo(18,69,50,64)..lineTo(91,31)..quadraticBezierTo(102,24,124,24)..lineTo(188,26)..quadraticBezierTo(207,27,220,43)..lineTo(242,64)..quadraticBezierTo(281,66,292,79)..lineTo(294,100)..lineTo(12,100)..close();
    canvas.drawPath(body,Paint()..shader=ui.Gradient.linear(const Offset(0,20),const Offset(0,105),dark?[const Color(0xffd7efff),const Color(0xff6e94b3),const Color(0xff284864)]:[const Color(0xfff5fbff),const Color(0xffa6c4d9),const Color(0xff6386a1)], [0, .5, 1]));
    final glass=Path()..moveTo(68,63)..lineTo(104,34)..lineTo(174,35)..lineTo(177,63)..close();
    canvas.drawPath(glass,Paint()..color=const Color(0xff153d58));
    canvas.drawPath(Path()..moveTo(184,35)..lineTo(198,37)..lineTo(224,64)..lineTo(186,63)..close(),Paint()..color=const Color(0xff153d58));
    for(final x in [65.0,242.0]){canvas.drawCircle(Offset(x,99),20,Paint()..color=const Color(0xff081a29));canvas.drawCircle(Offset(x,99),12,Paint()..color=const Color(0xffa6c0d2));canvas.drawCircle(Offset(x,99),6,Paint()..color=const Color(0xff3d5e75));}
    canvas.drawLine(const Offset(177,67),const Offset(179,94),Paint()..color=const Color(0xff55758d)..strokeWidth=1);
    canvas.drawLine(const Offset(26,78),const Offset(49,76),Paint()..color=const Color(0xffeafaff)..strokeWidth=5);
    canvas.drawLine(const Offset(279,78),const Offset(289,82),Paint()..color=const Color(0xffef856d)..strokeWidth=4);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant VehicleArt oldDelegate)=>oldDelegate.dark!=dark;
}
