import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Finite, local opening artwork. It never represents auth/loading progress.
class SplashRescueScene extends StatelessWidget {
  const SplashRescueScene({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0) * 4200;
    final car = Curves.easeOutCubic.transform((t / 950).clamp(0.0, 1.0));
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 390,
        height: 290,
        child: CustomPaint(
          foregroundPainter: _RescuePainter(
            t,
            Theme.of(context).brightness == Brightness.dark,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 4 + (car - 1) * 250,
                top: 139,
                width: 191,
                height: 73,
                child: Image.asset(
                  'assets/images/auth_journey_car.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescuePainter extends CustomPainter {
  const _RescuePainter(this.t, this.dark);
  final double t;
  final bool dark;
  double part(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  double ease(double v) => Curves.easeOutCubic.transform(v.clamp(0.0, 1.0));
  double mix(double a, double b, double v) => a + (b - a) * v;
  static const ice = Color(0xFFBCE8FF), navy = Color(0xFF173A53);
  void line(Canvas c, Offset a, Offset b, Color color, double width) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void box(Canvas c, Rect rect, Color color, [double r = 0]) => c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(r)),
    Paint()..color = color,
  );
  void poly(Canvas c, List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    c.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas c, Size size) {
    final shadow = dark ? const Color(0x66010C19) : const Color(0x224A8AAD);
    c.drawOval(const Rect.fromLTWH(12, 208, 184, 16), Paint()..color = shadow);
    c.drawOval(const Rect.fromLTWH(228, 208, 154, 16), Paint()..color = shadow);
    final ground = Path()
      ..moveTo(15, 222)
      ..quadraticBezierTo(195, 208, 375, 222);
    c.drawPath(
      ground,
      Paint()
        ..color = const Color(0x337DCCFF)
        ..style = PaintingStyle.stroke,
    );
    final car = ease(part(0, 950)), door = math.sin(part(900, 2100) * math.pi);
    if (door > .001) {
      c.save();
      c.translate((car - 1) * 250 - door * 12, 0);
      c.transform(Matrix4.skewY(-door * .12).storage);
      c.saveLayer(
        const Rect.fromLTWH(65, 140, 60, 65),
        Paint()..color = Colors.white.withValues(alpha: door),
      );
      poly(c, const [
        Offset(75, 162),
        Offset(111, 161),
        Offset(116, 196),
        Offset(78, 196),
      ], const Color(0xFF96AFC2));
      poly(c, const [
        Offset(77, 163),
        Offset(109, 162),
        Offset(111, 173),
        Offset(78, 174),
      ], navy);
      c.restore();
      c.restore();
    }
    final van = ease(part(350, 1250)),
        vd = math.sin(part(1200, 2250) * math.pi);
    c.save();
    c.translate((1 - van) * 240 + 385, 0);
    c.scale(-1, 1);
    final body = Path()
      ..moveTo(10, 147)
      ..quadraticBezierTo(10, 138, 20, 138)
      ..lineTo(95, 138)
      ..quadraticBezierTo(108, 138, 118, 154)
      ..lineTo(143, 179)
      ..lineTo(143, 205)
      ..lineTo(9, 205)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8AD7FF), Color(0xFF206FA9)],
        ).createShader(const Rect.fromLTWH(9, 138, 134, 67)),
    );
    c.drawPath(
      body,
      Paint()
        ..color = ice
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    poly(c, const [
      Offset(98, 145),
      Offset(109, 145),
      Offset(129, 174),
      Offset(98, 174),
    ], navy);
    line(
      c,
      const Offset(93, 144),
      const Offset(93, 199),
      ice.withValues(alpha: .4),
      1,
    );
    line(
      c,
      const Offset(12, 181),
      const Offset(136, 181),
      ice.withValues(alpha: .4),
      1,
    );
    box(c, const Rect.fromLTWH(4, 201, 145, 7), const Color(0xFF658AA2), 3);
    box(c, const Rect.fromLTWH(128, 183, 13, 6), const Color(0xFFDEF7FF), 2);
    line(c, const Offset(42, 158), const Offset(58, 174), ice, 4);
    c.drawArc(
      const Rect.fromLTWH(32, 149, 15, 15),
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..color = ice
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (vd > .001) {
      c.save();
      c.translate(vd * 8, 0);
      c.transform(Matrix4.skewY(vd * .09).storage);
      box(
        c,
        const Rect.fromLTWH(96, 177, 33, 23),
        const Color(0xFF3686BD).withValues(alpha: vd),
      );
      c.restore();
    }
    for (final x in [38.0, 119.0]) {
      c.save();
      c.translate(x, 205);
      c.rotate((1 - van) * math.pi * 3.45);
      c.drawCircle(Offset.zero, 15, Paint()..color = const Color(0xFF101F2D));
      c.drawCircle(
        Offset.zero,
        14,
        Paint()
          ..color = const Color(0xFF779AB2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.drawCircle(Offset.zero, 8, Paint()..color = const Color(0xFFB5D3E4));
      line(
        c,
        const Offset(-8, 0),
        const Offset(8, 0),
        const Color(0xFF3B586E),
        2,
      );
      line(
        c,
        const Offset(0, -8),
        const Offset(0, 8),
        const Color(0xFF3B586E),
        2,
      );
      c.restore();
    }
    c.restore();
    final exit = ease(part(1100, 1700)),
        walk = part(1550, 2300),
        settle = ease(walk);
    final bounce =
        math.sin(walk * math.pi * 5) * (walk > 0 && walk < 1 ? 1.1 : 0);
    final y = mix(119, 100, exit) + bounce;
    final reach = ease(part(2150, 2500)) * (1 - ease(part(3200, 3700)));
    final shake = part(2520, 3080);
    final hy = mix(
      65,
      44 + math.sin(shake * math.pi * 4) * 2.2 * math.sin(shake * math.pi),
      reach,
    );
    final stride =
        math.sin(walk * math.pi * 5) * (walk > 0 && walk < 1 ? 9.0 : 0.0);
    person(
      c,
      false,
      mix(96, 160, settle),
      y,
      mix(.9, 1, exit),
      part(1120, 1430),
      reach,
      hy,
      stride,
      shadow,
    );
    person(
      c,
      true,
      mix(299, 230, settle),
      y,
      mix(.9, 1, exit),
      part(1330, 1630),
      reach,
      hy,
      -stride,
      shadow,
    );
    final caseOpacity = part(1400, 1800);
    c.saveLayer(
      const Rect.fromLTWH(290, 185, 35, 35),
      Paint()..color = Colors.white.withValues(alpha: caseOpacity),
    );
    box(c, const Rect.fromLTWH(294, 195, 25, 20), const Color(0xFF466E88), 3);
    line(c, const Offset(301, 195), const Offset(301, 190), ice, 1.5);
    line(c, const Offset(301, 190), const Offset(311, 190), ice, 1.5);
    line(c, const Offset(311, 190), const Offset(311, 195), ice, 1.5);
    line(c, const Offset(294, 204), const Offset(319, 204), ice, 1);
    c.restore();
    final ring = part(2700, 3300);
    c.drawCircle(
      const Offset(195, 144),
      mix(6, 27, ease(ring)),
      Paint()
        ..color = ice.withValues(
          alpha: math.sin(ring * math.pi).clamp(0, 1) * .6,
        )
        ..style = PaintingStyle.stroke,
    );
  }

  void person(
    Canvas c,
    bool provider,
    double x,
    double y,
    double scale,
    double alpha,
    double reach,
    double hy,
    double stride,
    Color shadow,
  ) {
    if (alpha <= 0) return;
    c.save();
    c.translate(x, y);
    c.scale(scale);
    c.saveLayer(
      const Rect.fromLTWH(-45, -20, 90, 150),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    final shirt = provider ? const Color(0xFF358BC0) : const Color(0xFFB0C8D9),
        skin = provider ? const Color(0xFFC79673) : const Color(0xFFE5B794);
    c.drawOval(const Rect.fromLTWH(-16, 117, 32, 8), Paint()..color = shadow);
    for (final sign in [-1.0, 1.0]) {
      c.save();
      c.translate(sign * 5, 66);
      c.rotate(-stride * sign * math.pi / 180);
      line(c, Offset.zero, Offset(sign * 3, 47), const Color(0xFF203B52), 9);
      line(
        c,
        Offset(sign * 3 - 5, 49),
        Offset(sign * 3 + 5, 49),
        const Color(0xFF0B1B2A),
        6,
      );
      c.restore();
    }
    final torso = Path()
      ..moveTo(-12, 18)
      ..quadraticBezierTo(0, 12, 12, 18)
      ..lineTo(15, 67)
      ..lineTo(-14, 67)
      ..close();
    c.drawPath(torso, Paint()..color = shirt);
    if (provider) {
      line(c, const Offset(-11, 34), const Offset(12, 34), ice, 1.5);
      line(c, const Offset(0, 19), const Offset(0, 65), ice, 1.5);
      box(c, const Rect.fromLTWH(4, 23, 5, 8), ice, 1);
    }
    final outside = provider ? 1.0 : -1.0;
    final relaxed = Path()
      ..moveTo(outside * 12, 22)
      ..lineTo(outside * 21, 43)
      ..lineTo(outside * 18, 65);
    c.drawPath(
      relaxed,
      Paint()
        ..color = shirt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawCircle(Offset(outside * 18, 66), 4, Paint()..color = skin);
    box(c, const Rect.fromLTWH(-4, 5, 8, 13), skin, 3);
    c.drawOval(const Rect.fromLTWH(-10, -13, 20, 26), Paint()..color = skin);
    final hair = Path()
      ..moveTo(-10, 1)
      ..quadraticBezierTo(-13, -15, 1, -15)
      ..quadraticBezierTo(14, -14, 10, -1)
      ..lineTo(4, -8)
      ..close();
    c.drawPath(hair, Paint()..color = const Color(0xFF20394D));
    final inside = -outside, hx = mix(15, 35, reach) * inside;
    final arm = Path()
      ..moveTo(9 * inside, 24)
      ..quadraticBezierTo(
        mix(13, 22, reach) * inside,
        mix(43, 45, reach),
        hx,
        hy,
      );
    c.drawPath(
      arm,
      Paint()
        ..color = shirt
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    c.drawCircle(Offset(hx, hy), 4.1, Paint()..color = skin);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _RescuePainter old) =>
      old.t != t || old.dark != dark;
}
