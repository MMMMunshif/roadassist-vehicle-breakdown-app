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
          final file = File('build/previews/studio-${provider ? "provider" : "driver"}-${dark ? "dark" : "light"}.png');
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
      g(9),t(provider?'Make today count.':'Go further. Worry less.',26,w:FontWeight.w800),g(11),
      Row(children:[Icon(Icons.location_on_outlined,color:blue,size:14),const SizedBox(width:5),t('Colombo, Sri Lanka',11,c:muted),const SizedBox(width:5),Icon(Icons.expand_more_rounded,color:muted,size:15),const Spacer(),if(!provider)t('Change',10,c:blue,w:FontWeight.w700)]),
      g(21), if(provider)...partner() else ...driver(),
    ]),
    Positioned(bottom:16,left:20,right:20,child:ClipRRect(borderRadius:BorderRadius.circular(28),child:BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:22,sigmaY:22),child:Container(height:73,padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:(dark?const Color(0xff183347):Colors.white).withValues(alpha:.78),borderRadius:BorderRadius.circular(28),border:Border.all(color:(dark?Colors.white:blue).withValues(alpha:.2))),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[nav(Icons.grid_view_rounded,provider?'Workspace':'Home',true),nav(Icons.receipt_long_outlined,'Requests',false),if(provider)nav(Icons.work_outline_rounded,'Jobs',false),nav(Icons.forum_outlined,'Messages',false),nav(Icons.person_outline_rounded,'You',false)]))))),
  ])));
  Widget nav(IconData i,String s,bool selected)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:selected?blue.withValues(alpha:.16):Colors.transparent,borderRadius:BorderRadius.circular(19)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(i,color:selected?blue:muted,size:21),g(4),t(s,8,c:selected?blue:muted,w:selected?FontWeight.w800:FontWeight.w600)]));
  Widget heading(String a,String b)=>Row(children:[t(a,17,w:FontWeight.w800),const Spacer(),t(b,10,c:blue,w:FontWeight.w700)]);

  List<Widget> driver()=>[
    ClipRRect(borderRadius:BorderRadius.circular(30),child:SizedBox(height:276,child:Stack(fit:StackFit.expand,children:[
      Image.asset('assets/images/roadassist_home_scene.png',fit:BoxFit.cover),
      const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0x5504192d),Color(0x3304192d),Color(0xff051c32)],stops:[0,.35,1]))),
      Positioned(top:18,left:18,right:18,child:Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.28),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white.withValues(alpha:.26))),child:Row(children:[const Icon(Icons.shield_outlined,color:Colors.white,size:13),const SizedBox(width:5),t('YOUR ROADSIDE COMPANION',8,c:Colors.white,w:FontWeight.w800)])),const Spacer(),const Icon(Icons.north_east_rounded,color:Colors.white,size:21)])),
      Positioned(left:20,bottom:79,right:20,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Unexpected stop.\nUnstoppable you.',27,c:Colors.white,w:FontWeight.w800),g(7),t('The right help. Right when you need it.',10,c:const Color(0xffc5d7e9))])),
      Positioned(left:17,right:17,bottom:17,child:action('Request roadside help')),
    ]))),
    g(13),card(Row(children:[Container(width:45,height:45,decoration:BoxDecoration(color:blue.withValues(alpha:.12),borderRadius:BorderRadius.circular(16)),child:Icon(Icons.directions_car_filled_outlined,color:blue,size:25)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Toyota Aqua',14,w:FontWeight.w800),g(4),t('CAB-1234 / Your default vehicle',9,c:muted)])),circle(Icons.swap_horiz_rounded)]),padding:const EdgeInsets.all(13),radius:21),
    g(21),heading('One tap closer.','ALL SERVICES'),g(12),
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:5,child:Container(height:150,padding:const EdgeInsets.all(17),decoration:BoxDecoration(gradient:LinearGradient(colors:dark?[const Color(0xff164879),const Color(0xff10334e)]:[const Color(0xffcfe7ff),const Color(0xffedf6ff)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(25),border:Border.all(color:blue.withValues(alpha:.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.build_outlined,color:blue,size:29),const Spacer(),Icon(Icons.north_east_rounded,color:blue,size:18)]),const Spacer(),t('Mechanic',17,w:FontWeight.w800),g(5),t('Get to the root\nof the problem.',10,c:muted)]))),const SizedBox(width:11),Expanded(flex:5,child:Column(children:[mini(Icons.tire_repair_outlined,'Flat tyre'),g(10),mini(Icons.battery_charging_full_rounded,'Battery'),g(10),mini(Icons.local_shipping_outlined,'Towing')]))]),
    g(15),Row(children:[Icon(Icons.lock_outline_rounded,color:muted,size:13),const SizedBox(width:6),t('Clear fees. You approve before you pay.',10,c:muted)]),
  ];
  Widget tile(IconData i,String a,String b)=>card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(i,color:blue,size:25),const Spacer(),Icon(Icons.north_east_rounded,color:muted,size:15)]),g(15),t(a,13,w:FontWeight.w800),g(3),t(b,9,c:muted)]),padding:const EdgeInsets.all(15),radius:21);
  Widget mini(IconData i,String s)=>card(Row(children:[Icon(i,size:20,color:blue),const SizedBox(width:9),t(s,11,w:FontWeight.w700),const Spacer(),Icon(Icons.chevron_right_rounded,color:muted,size:16)]),padding:const EdgeInsets.all(14),radius:19);

  List<Widget> partner()=>[
    card(Row(children:[Container(width:9,height:9,decoration:const BoxDecoration(color:Color(0xff36d8ad),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Online. Open for opportunities.',12,w:FontWeight.w800),g(4),t('Location updated / Colombo',9,c:muted)])),Container(width:44,height:27,alignment:Alignment.centerRight,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xff20bc92),borderRadius:BorderRadius.circular(20)),child:const CircleAvatar(radius:10.5,backgroundColor:Colors.white))]),padding:const EdgeInsets.all(14),radius:21),
    g(13),
    Container(height:176,padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff116ced),Color(0xff054ac4)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(28)),child:Stack(children:[Positioned(right:-9,top:13,child:CustomPaint(size:const Size(138,90),painter:EarningArt())),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[t('TODAY / COLLECTED',9,c:Colors.white.withValues(alpha:.8),w:FontWeight.w800),const Spacer(),const Icon(Icons.north_east_rounded,color:Colors.white,size:19)]),g(15),t('Rs. 4,000',34,c:Colors.white,w:FontWeight.w800),const Spacer(),Row(children:[smallGlass('03','Jobs completed'),const SizedBox(width:10),smallGlass('4.9','Driver rating')])])])),
    g(21),heading('Next in your lane.','01 REQUEST'),g(12),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[tag('DIRECT TO YOU',c:dark?const Color(0xff6ae7be):const Color(0xff008760)),const Spacer(),t('JUST NOW',8,c:muted,w:FontWeight.w800)]),g(15),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Engine trouble.',23,w:FontWeight.w800),g(5),t('Toyota Aqua / CAB-1234',10,c:muted)])),Container(width:47,height:47,decoration:BoxDecoration(color:blue.withValues(alpha:.12),borderRadius:BorderRadius.circular(16)),child:Icon(Icons.car_repair_rounded,color:blue,size:27))]),g(16),
      Row(children:[Expanded(child:info('DISTANCE','1.8 km',Icons.near_me_outlined)),Container(width:1,height:35,color:blue.withValues(alpha:.18)),const SizedBox(width:18),Expanded(child:info('VISIT FEE','Rs. 120',Icons.receipt_long_outlined))]),g(16),Container(height:1,color:blue.withValues(alpha:.12)),g(13),Row(children:[CircleAvatar(radius:17,backgroundColor:blue.withValues(alpha:.13),child:t('AA',10,c:blue,w:FontWeight.w800)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t('Ahamed Affan',11,w:FontWeight.w800),g(3),t('Colombo 07',9,c:muted)])),Icon(Icons.chevron_right_rounded,color:muted,size:19)]),g(16),action('View request'),
    ]),radius:27),
    g(13),card(Row(children:[Icon(Icons.account_balance_wallet_outlined,color:blue,size:20),const SizedBox(width:10),Expanded(child:t('Payment follow-ups',11,w:FontWeight.w700)),Icon(Icons.arrow_forward_rounded,color:muted,size:18)]),padding:const EdgeInsets.all(14),radius:20),
  ];
  Widget info(String label,String value,IconData icon)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[t(label,8,c:muted,w:FontWeight.w800),g(6),Row(children:[Icon(icon,color:blue,size:15),const SizedBox(width:7),t(value,18,w:FontWeight.w800)])]);
  Widget smallGlass(String n,String label)=>Expanded(child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.13),borderRadius:BorderRadius.circular(13),border:Border.all(color:Colors.white.withValues(alpha:.13))),child:Row(children:[t(n,16,c:Colors.white,w:FontWeight.w800),const SizedBox(width:9),Expanded(child:t(label,8,c:Colors.white.withValues(alpha:.85)))])));

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

class EarningArt extends CustomPainter {
 @override void paint(Canvas c,Size s){
   for(final radius in [30.0,46.0,62.0]){c.drawCircle(Offset(s.width*.62,s.height*.45),radius,Paint()..color=Colors.white.withValues(alpha:.09)..style=PaintingStyle.stroke..strokeWidth=1);}
   c.drawLine(Offset(s.width*.24,s.height*.72),Offset(s.width*.86,s.height*.18),Paint()..color=Colors.white.withValues(alpha:.17)..strokeWidth=18..strokeCap=StrokeCap.round);
   final p=Path()..moveTo(s.width*.61,s.height*.18)..lineTo(s.width*.87,s.height*.18)..lineTo(s.width*.87,s.height*.47);
   c.drawPath(p,Paint()..color=Colors.white.withValues(alpha:.18)..strokeWidth=17..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
 }
 @override bool shouldRepaint(covariant EarningArt oldDelegate)=>false;
}
