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
          await (FontLoader('Manrope')..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
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
          final file = File('build/previews/atelier-${provider ? "provider" : "driver"}-${dark ? "dark" : "light"}.png');
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
 final bool provider,dark;
 Color get ink=>dark?const Color(0xfff1f5fa):const Color(0xff142a3c);
 Color get quiet=>dark?const Color(0xff9bacbd):const Color(0xff637689);
 Color get accent=>dark?const Color(0xff85c2ff):const Color(0xff0866c5);
 Color get panel=>dark?const Color(0xff122a3c):const Color(0xfffcfdff);
 Widget tx(String s,double size,{Color? color,FontWeight weight=FontWeight.w500,double spacing=0})=>Text(s,style:TextStyle(fontFamily:'Manrope',fontSize:size,height:1.22,letterSpacing:spacing,color:color??ink,fontWeight:weight));
 Widget gap(double n)=>SizedBox(height:n);
 Widget label(String s)=>tx(s,9,color:quiet,weight:FontWeight.w700,spacing:1.3);
 Widget glyph(String type,{double size=24,Color? color})=>SizedBox(width:size,height:size,child:CustomPaint(painter:PrecisionIcon(type,color??ink)));
 Widget line()=>Container(height:1,color:quiet.withValues(alpha:.20));
 Widget box(Widget child,{EdgeInsets padding=const EdgeInsets.all(19),Color? color,double radius=23})=>Container(padding:padding,decoration:BoxDecoration(color:color??panel.withValues(alpha:.91),borderRadius:BorderRadius.circular(radius),border:Border.all(color:(dark?Colors.white:const Color(0xffacbfd0)).withValues(alpha:dark ? .12 : .40))),child:child);
 Widget smallButton(String type)=>box(glyph(type,size:18),padding:const EdgeInsets.all(11),radius:50);
 Widget button(String s,{bool outline=false})=>Container(height:49,padding:const EdgeInsets.symmetric(horizontal:17),decoration:BoxDecoration(color:outline?Colors.transparent:ink,border:Border.all(color:outline?quiet.withValues(alpha:.4):Colors.transparent),borderRadius:BorderRadius.circular(14)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[tx(s,12,color:outline?ink:(dark?const Color(0xff142a3c):Colors.white),weight:FontWeight.w700),if(!outline)...[const Spacer(),glyph('arrow',size:18,color:dark?const Color(0xff142a3c):Colors.white)]]));
 @override Widget build(BuildContext context)=>RaScaffold(body:SafeArea(child:Stack(children:[
 ListView(padding:const EdgeInsets.fromLTRB(24,20,24,115),children:[
 Row(children:[Image.asset('assets/images/roadassist_mark.png',width:30,height:34),const SizedBox(width:9),tx('RoadAssist',20,weight:FontWeight.w800,spacing:-.7),const Spacer(),smallButton(dark?'moon':'sun'),const SizedBox(width:8),smallButton('bell')]),
 gap(28),Row(children:[label(provider?'PARTNER / WORKSPACE':'DRIVER / OVERVIEW'),const Spacer(),tx(provider?'Munshif':'Ahamed',11,color:quiet)]),gap(12),
 tx(provider?"Ready for\nwhat's next.":'Roadside care.\nOn your terms.',38,weight:FontWeight.w600,spacing:-1.7),gap(15),
 if(provider)...partner() else ...driver(),
 ]),
 Positioned(left:23,right:23,bottom:17,child:ClipRRect(borderRadius:BorderRadius.circular(25),child:BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:20,sigmaY:20),child:Container(height:71,padding:const EdgeInsets.symmetric(horizontal:11),decoration:BoxDecoration(color:(dark?const Color(0xff142c40):Colors.white).withValues(alpha:.86),borderRadius:BorderRadius.circular(25),border:Border.all(color:quiet.withValues(alpha:.25))),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[nav('home',provider?'Workspace':'Home',true),nav('receipt','Requests',false),if(provider)nav('case','Jobs',false),nav('message','Messages',false),nav('profile','Account',false)]))))),
 ])));
 Widget nav(String i,String name,bool selected)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[glyph(i,size:21,color:selected?accent:quiet),gap(5),tx(name,8,color:selected?ink:quiet,weight:selected?FontWeight.w800:FontWeight.w500),gap(5),Container(width:15,height:2,decoration:BoxDecoration(color:selected?accent:Colors.transparent,borderRadius:BorderRadius.circular(3)))]);
 Widget section(String title,String action)=>Row(children:[tx(title,16,weight:FontWeight.w700,spacing:-.4),const Spacer(),tx(action,10,color:quiet),const SizedBox(width:6),glyph('arrow',size:12,color:quiet)]);
 List<Widget> driver()=>[
 Row(children:[glyph('pin',size:14,color:accent),const SizedBox(width:7),tx('Colombo, Sri Lanka',11,color:quiet),const Spacer(),tx('Edit location',10,color:accent,weight:FontWeight.w700)]),gap(24),
 box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label('ASSISTANCE, SIMPLIFIED'),gap(14),tx('A better way\nback on the road.',23,weight:FontWeight.w600,spacing:-.6),gap(11),tx('Verified providers.\nCharges you approve.',11,color:quiet)])),SizedBox(width:109,height:126,child:CustomPaint(painter:RoadSculpture(dark)))]),gap(22),button('Request assistance')]),radius:25),
 gap(25),section('Find your service','View all'),gap(13),
 Row(children:[Expanded(child:service('tool','Mechanic')),const SizedBox(width:10),Expanded(child:service('wheel','Tyre care')),const SizedBox(width:10),Expanded(child:service('battery','Battery'))]),
 gap(24),section('Your vehicle','Garage'),gap(12),
 box(Row(children:[glyph('car',size:36,color:accent),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[tx('Toyota Aqua',14,weight:FontWeight.w700),gap(5),tx('CAB-1234  /  Hybrid',10,color:quiet)])),glyph('arrow',size:18,color:quiet)]),padding:const EdgeInsets.symmetric(horizontal:17,vertical:18),radius:20),
 gap(21),Row(children:[glyph('shield',size:15,color:quiet),const SizedBox(width:8),tx('Your approval. Before every payment.',10,color:quiet)]),
 ];
 Widget service(String icon,String s)=>box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[glyph(icon,size:29,color:accent),gap(18),tx(s,11,weight:FontWeight.w700)]),padding:const EdgeInsets.all(15),radius:18);
 List<Widget> partner()=>[
 box(Row(children:[Container(width:7,height:7,decoration:const BoxDecoration(color:Color(0xff39c7a0),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:tx('Available for requests',12,weight:FontWeight.w600)),Container(width:39,height:23,padding:const EdgeInsets.all(3),alignment:Alignment.centerRight,decoration:BoxDecoration(color:accent,borderRadius:BorderRadius.circular(20)),child:Container(width:17,height:17,decoration:BoxDecoration(color:dark?const Color(0xff123049):Colors.white,shape:BoxShape.circle)))]),padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),radius:17),gap(24),
 section('Incoming request','01 nearby'),gap(13),
 box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:accent.withValues(alpha:.10),borderRadius:BorderRadius.circular(7)),child:tx('DIRECT REQUEST',8,color:accent,weight:FontWeight.w800,spacing:.7)),const Spacer(),tx('Just now',9,color:quiet)]),gap(19),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[tx('General mechanic',22,weight:FontWeight.w600,spacing:-.7),gap(7),tx('Engine will not start.',12,color:quiet)])),glyph('tool',size:35,color:accent)]),gap(21),line(),gap(16),
 Row(children:[Expanded(child:detail('DISTANCE','1.8 km')),Expanded(child:detail('VISIT FEE','Rs. 120')),Expanded(child:detail('VEHICLE','Toyota Aqua'))]),gap(17),line(),gap(15),Row(children:[Container(width:32,height:32,alignment:Alignment.center,decoration:BoxDecoration(color:accent.withValues(alpha:.1),shape:BoxShape.circle),child:tx('AA',10,color:accent,weight:FontWeight.w700)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[tx('Ahamed Affan',11,weight:FontWeight.w700),gap(3),tx('Colombo 07',9,color:quiet)])),glyph('shield',size:16,color:quiet)]),gap(19),Row(children:[Expanded(flex:2,child:button('Dismiss',outline:true)),const SizedBox(width:10),Expanded(flex:3,child:button('Review request'))])]),radius:23),
 gap(24),section('Today, at a glance','Earnings'),gap(13),box(Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label('COLLECTED'),gap(8),tx('Rs. 4,000',24,weight:FontWeight.w600,spacing:-1)])),Container(width:1,height:37,color:quiet.withValues(alpha:.2)),const SizedBox(width:22),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label('COMPLETED'),gap(8),tx('03 jobs',20,weight:FontWeight.w600)])]),padding:const EdgeInsets.all(18),radius:19),
 ];
 Widget detail(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[tx(a,7.5,color:quiet,weight:FontWeight.w700,spacing:1),gap(8),tx(b,12,weight:FontWeight.w700)]);
}
class PrecisionIcon extends CustomPainter {
 PrecisionIcon(this.type,this.color);final String type;final Color color;
 @override void paint(Canvas canvas,Size size){
 canvas.save();canvas.scale(size.width/24,size.height/24);
 final pen=Paint()..color=color..strokeWidth=1.5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
 void path(List<Offset> points,{bool close=false}){final p=Path()..addPolygon(points,close);canvas.drawPath(p,pen);}
 void line(double x,double y,double a,double b)=>canvas.drawLine(Offset(x,y),Offset(a,b),pen);
 switch(type){
 case 'arrow':line(5,12,19,12);path([const Offset(14,7),const Offset(19,12),const Offset(14,17)]);break;
 case 'home':path([const Offset(3,10),const Offset(12,3),const Offset(21,10)]);path([const Offset(5,9),const Offset(5,21),const Offset(10,21),const Offset(10,15),const Offset(14,15),const Offset(14,21),const Offset(19,21),const Offset(19,9)]);break;
 case 'message':canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3,4,18,14),const Radius.circular(4)),pen);path([const Offset(7,18),const Offset(6,22),const Offset(12,18)]);line(7,9,17,9);line(7,13,13,13);break;
 case 'receipt':path([const Offset(5,3),const Offset(8,5),const Offset(12,3),const Offset(16,5),const Offset(19,3),const Offset(19,21),const Offset(15,19),const Offset(12,21),const Offset(9,19),const Offset(5,21)],close:true);line(9,9,15,9);line(9,13,15,13);break;
 case 'profile':canvas.drawCircle(const Offset(12,7),4,pen);canvas.drawPath(Path()..moveTo(4,22)..lineTo(4,19)..quadraticBezierTo(4,13,12,13)..quadraticBezierTo(20,13,20,19)..lineTo(20,22),pen);break;
 case 'pin':canvas.drawPath(Path()..moveTo(12,22)..cubicTo(9,18,4,13,4,9)..arcToPoint(const Offset(20,9),radius:const Radius.circular(8))..cubicTo(20,13,15,18,12,22),pen);canvas.drawCircle(const Offset(12,9),2.5,pen);break;
 case 'bell':canvas.drawPath(Path()..moveTo(4,17)..lineTo(6,14)..lineTo(6,9)..arcToPoint(const Offset(18,9),radius:const Radius.circular(6))..lineTo(18,14)..lineTo(20,17)..close(),pen);canvas.drawArc(const Rect.fromLTWH(9,17,6,6),0,3.14,false,pen);line(12,1,12,3);break;
 case 'shield':path([const Offset(12,2),const Offset(21,6),const Offset(19,16),const Offset(12,22),const Offset(5,16),const Offset(3,6)],close:true);path([const Offset(8,11),const Offset(11,14),const Offset(16,9)]);break;
 case 'car':path([const Offset(3,12),const Offset(6,5),const Offset(18,5),const Offset(21,12),const Offset(21,19),const Offset(3,19)],close:true);line(3,12,21,12);line(7,16,8,16);line(16,16,17,16);line(5,19,5,22);line(19,19,19,22);break;
 case 'battery':canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5,4,14,18),const Radius.circular(3)),pen);line(9,1,15,1);path([const Offset(13,8),const Offset(9,13),const Offset(15,13),const Offset(11,18)]);break;
 case 'wheel':canvas.drawOval(const Rect.fromLTWH(5,2,14,20),pen);canvas.drawOval(const Rect.fromLTWH(9,6,6,12),pen);line(6,6,10,8);line(5,12,9,12);line(6,18,10,16);line(14,8,18,6);line(15,12,19,12);line(14,16,18,18);break;
 case 'tool':canvas.drawPath(Path()..moveTo(14,3)..lineTo(14,8)..lineTo(19,8)..lineTo(21,4)..cubicTo(24,12,18,16,14,14)..lineTo(6,22)..lineTo(2,18)..lineTo(10,10)..cubicTo(8,6,10,2,14,3),pen);break;
 case 'case':canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3,7,18,14),const Radius.circular(3)),pen);path([const Offset(8,7),const Offset(8,3),const Offset(16,3),const Offset(16,7)]);line(3,13,21,13);line(12,12,12,15);break;
 case 'sun':canvas.drawCircle(const Offset(12,12),4,pen);for(final o in [const Offset(12,2),const Offset(12,22),const Offset(2,12),const Offset(22,12),const Offset(5,5),const Offset(19,5),const Offset(5,19),const Offset(19,19)]){canvas.drawCircle(o,1,Paint()..color=color);}break;
 default:canvas.drawPath(Path()..moveTo(19,16)..arcToPoint(const Offset(8,4),radius:const Radius.circular(9),largeArc:true)..arcToPoint(const Offset(19,16),radius:const Radius.circular(8),clockwise:false),pen);
 }
 canvas.restore();
 }
 @override bool shouldRepaint(covariant PrecisionIcon o)=>o.type!=type||o.color!=color;
}
class RoadSculpture extends CustomPainter {
 RoadSculpture(this.dark);final bool dark;
 @override void paint(Canvas c,Size s){
 final center=Offset(s.width*.5,s.height*.55);
 for(final r in [40.0,50.0]){c.drawCircle(center,r,Paint()..color=const Color(0xff61aefb).withValues(alpha:.15)..style=PaintingStyle.stroke..strokeWidth=1);}
 final road=Path()..moveTo(s.width*.26,s.height*.98)..cubicTo(s.width*.16,s.height*.68,s.width*.90,s.height*.61,s.width*.64,s.height*.20);
 c.drawPath(road,Paint()..color=const Color(0xff1789f0).withValues(alpha:.16)..style=PaintingStyle.stroke..strokeWidth=28..strokeCap=StrokeCap.round);
 c.drawPath(road,Paint()..shader=ui.Gradient.linear(const Offset(0,15),Offset(s.width,s.height),[const Color(0xffa7dbff),const Color(0xff227ed2)])..style=PaintingStyle.stroke..strokeWidth=19..strokeCap=StrokeCap.round);
 c.drawPath(road,Paint()..color=const Color(0xff0c457b)..style=PaintingStyle.stroke..strokeWidth=1);
 final pin=Offset(s.width*.64,s.height*.18);
 c.drawCircle(pin,15,Paint()..color=dark?const Color(0xffeaf6ff):const Color(0xff174e79));
 c.drawCircle(pin,5,Paint()..color=dark?const Color(0xff2376c0):const Color(0xffcce9ff));
 }
 @override bool shouldRepaint(covariant RoadSculpture o)=>o.dark!=dark;
}
