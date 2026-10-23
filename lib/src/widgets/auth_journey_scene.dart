import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Local, event-driven motion. This controller never decides whether auth passed.
enum AuthJourneyPhase { idle, typing, password, authenticating, success }

class AuthJourneyController extends ChangeNotifier {
  AuthJourneyPhase _phase = AuthJourneyPhase.idle;
  AuthJourneyPhase get phase => _phase;
  double _progress = 0;
  double get progress => _progress;
  bool _privacy = true;
  bool get privacy => _privacy;
  Future<void> Function()? _finish;

  void update({AuthJourneyPhase? phase, double? progress, bool? privacy}) {
    final next = phase ?? _phase;
    final amount = (progress ?? _progress).clamp(0.0, 1.0);
    final tint = privacy ?? _privacy;
    if (next == _phase && amount == _progress && tint == _privacy) return;
    _phase = next;
    _progress = amount;
    _privacy = tint;
    notifyListeners();
  }

  Future<void> complete() async {
    update(phase: AuthJourneyPhase.success);
    await _finish?.call();
  }
}

/// The same silver car arrives, protects password entry, and leaves on success.
/// No remote assets, sound, timers, or perpetual idle animation.
class AuthJourneyScene extends StatefulWidget {
  const AuthJourneyScene({
    super.key,
    required this.controller,
    this.registration = false,
    this.provider = false,
  });
  final AuthJourneyController controller;
  final bool registration;
  final bool provider;
  @override
  State<AuthJourneyScene> createState() => _AuthJourneySceneState();
}

class _AuthJourneySceneState extends State<AuthJourneyScene>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<AuthJourneyScene> {
  late final arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final travel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final departure = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  @override
  bool get wantKeepAlive => true;

  bool reduced = false;
  bool started = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    widget.controller.addListener(_sync);
    widget.controller._finish = _finish;
  }

  @override
  void didUpdateWidget(covariant AuthJourneyScene old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider ||
        old.registration != widget.registration) {
      departure.reset();
      if (reduced) {
        arrival.value = 1;
      } else {
        arrival.forward(from: 0);
      }
    }

    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      old.controller._finish = null;
      _attach();
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (!started) {
      started = true;
      if (reduced) {
        arrival.value = 1;
      } else {
        arrival.forward();
      }
    }
    if (reduced) {
      arrival.value = 1;
      departure.stop();
      travel.stop();
    }
    _sync();
  }

  Future<void> _finish() async {
    if (reduced || !mounted) return;
    try {
      await departure.forward(from: 0).orCancel;
    } on TickerCanceled {
      /* Route disposed. */
    }
  }

  void _sync() {
    final moving = widget.controller.phase == AuthJourneyPhase.authenticating;
    if (moving && !reduced) {
      if (!travel.isAnimating) travel.repeat();
    } else {
      travel.stop();
    }
    if (widget.controller.phase != AuthJourneyPhase.success &&
        departure.value != 0)
      departure.reset();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    widget.controller._finish = null;
    arrival.dispose();
    travel.dispose();
    departure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final phase = widget.controller.phase;
    final private =
        phase == AuthJourneyPhase.password && widget.controller.privacy;
    final lit =
        phase == AuthJourneyPhase.authenticating ||
        phase == AuthJourneyPhase.success;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: compact ? 82 : 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                constraints.maxWidth * .98,
                compact ? 200.0 : 390.0,
              );
              final height = width * (774 / 2032);
              return AnimatedBuilder(
                animation: Listenable.merge([arrival, travel, departure]),
                builder: (context, _) {
                  if (widget.provider) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _ProviderArrivalPainter(
                        arrival: arrival.value,
                        departure: departure.value,
                        working: lit,
                        progress: widget.controller.progress,
                        dark: dark,
                      ),
                    );
                  }
                  final entered = Curves.easeOutCubic.transform(arrival.value);
                  final leaving = Curves.easeInCubic.transform(departure.value);
                  final settling =
                      math.sin(arrival.value * math.pi * 3) *
                      (1 - arrival.value) *
                      2;
                  final offset =
                      (entered - 1) * constraints.maxWidth +
                      leaving * (constraints.maxWidth + width) +
                      (widget.registration
                          ? widget.controller.progress * 12
                          : 0);
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _JourneyRoadPainter(dark, travel.value, lit),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, -.1),
                        child: Transform.translate(
                          offset: Offset(offset, reduced ? 0 : settling),
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (lit)
                                  Positioned(
                                    right: -28,
                                    top: height * .43,
                                    child: Container(
                                      width: 80,
                                      height: 27,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF84D9FF,
                                            ).withValues(alpha: .42),
                                            const Color(0x0084D9FF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                Image.asset(
                                  'assets/images/auth_journey_car.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                if (!reduced)
                                  for (final cx in [.169, .756])
                                    _wheel(
                                      width,
                                      height,
                                      cx,
                                      (arrival.isAnimating
                                              ? arrival.value * 2
                                              : 0) +
                                          (lit ? travel.value * 2 : 0) +
                                          departure.value * 3,
                                    ),
                                AnimatedOpacity(
                                  opacity: private ? .88 : 0,
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  child: CustomPaint(
                                    painter: _JourneyPrivacyPainter(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.registration && !compact)
                        Positioned(
                          left: 34,
                          right: 34,
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(3, (index) {
                              final active =
                                  widget.controller.progress >= (index + 1) / 3;
                              return AnimatedContainer(
                                duration: reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                width: active ? 32 : 24,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withValues(alpha: .45),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wheel(double width, double height, double cx, double turns) {
    final radius = width * .047;
    final x = width * cx;
    final y = height * .729;
    // Rotate a clipped view of the same immutable image, not a second asset.
    return Positioned(
      left: x - radius,
      top: y - radius,
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: Transform.rotate(
          angle: turns * math.pi * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: radius - x,
                top: radius - y,
                width: width,
                height: height,
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

class _JourneyPrivacyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF092235);
    final rear = Path()
      ..moveTo(size.width * .184, size.height * .283)
      ..lineTo(size.width * .260, size.height * .162)
      ..lineTo(size.width * .404, size.height * .140)
      ..lineTo(size.width * .417, size.height * .339)
      ..lineTo(size.width * .182, size.height * .334)
      ..close();
    final front = Path()
      ..moveTo(size.width * .438, size.height * .147)
      ..lineTo(size.width * .528, size.height * .171)
      ..lineTo(size.width * .641, size.height * .328)
      ..lineTo(size.width * .447, size.height * .343)
      ..close();
    canvas.drawPath(rear, p);
    canvas.drawPath(front, p);
  }

  @override
  bool shouldRepaint(covariant _JourneyPrivacyPainter oldDelegate) => false;
}

class _JourneyRoadPainter extends CustomPainter {
  _JourneyRoadPainter(this.dark, this.travel, this.lit);
  final bool dark, lit;
  final double travel;
  @override
  void paint(Canvas c, Size s) {
    final y = s.height * .76;
    final path = Path()
      ..moveTo(0, y + 12)
      ..cubicTo(s.width * .25, y - 4, s.width * .65, y + 15, s.width, y - 3);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3199F5).withValues(alpha: lit ? .30 : .12)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF47B6FF).withValues(alpha: dark ? .55 : .35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    for (double x = -30; x < s.width + 30; x += 30) {
      final dx = x - travel * 30;
      c.drawLine(
        Offset(dx, y + 9),
        Offset(dx + 10, y + 9),
        Paint()
          ..color = const Color(0xFF68BFFF).withValues(alpha: lit ? .55 : .20)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JourneyRoadPainter o) =>
      o.dark != dark || o.travel != travel || o.lit != lit;
}

/// Code-native artwork: the van arrives, wheels settle, then the technician steps
/// forward. The scene remains static when idle and respects reduced motion.
class _ProviderArrivalPainter extends CustomPainter {
  const _ProviderArrivalPainter({
    required this.arrival,
    required this.departure,
    required this.working,
    required this.progress,
    required this.dark,
  });
  final double arrival, departure, progress;
  final bool working, dark;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    final scale = math.min(size.width / 360, size.height / 190);
    c.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 190 * scale) / 2,
    );
    c.scale(scale);
    void box(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 0,
    ]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        Paint()..color = color,
      );
    }

    void line(Offset a, Offset b, Color color, double width) {
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    const ice = Color(0xFFB4E7FF),
        blue = Color(0xFF3F94C6),
        skin = Color(0xFFE8B997);
    c.drawOval(
      const Rect.fromLTWH(25, 159, 305, 15),
      Paint()..color = Colors.black.withValues(alpha: dark ? .22 : .08),
    );
    final arrive = Curves.easeOutCubic.transform(
      (arrival / .70).clamp(0.0, 1.0),
    );
    c.save();
    c.translate(
      (arrive - 1) * 390 + Curves.easeInCubic.transform(departure) * 450,
      0,
    );
    final body = Path()
      ..moveTo(27, 76)
      ..quadraticBezierTo(27, 63, 42, 63)
      ..lineTo(151, 63)
      ..quadraticBezierTo(168, 63, 179, 80)
      ..lineTo(207, 114)
      ..lineTo(207, 148)
      ..lineTo(26, 148)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81D0FF), Color(0xFF155B99)],
        ).createShader(const Rect.fromLTWH(26, 63, 181, 85)),
    );
    c.drawPath(
      body,
      Paint()
        ..color = ice
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    c.drawPath(
      Path()
        ..moveTo(148, 74)
        ..lineTo(163, 74)
        ..lineTo(190, 109)
        ..lineTo(148, 109)
        ..close(),
      Paint()..color = const Color(0xFF123752),
    );
    box(35, 75, 98, 36, ice.withValues(alpha: .13));
    line(
      const Offset(140, 70),
      const Offset(140, 145),
      ice.withValues(alpha: .4),
      1,
    );
    line(
      const Offset(31, 119),
      const Offset(199, 119),
      ice.withValues(alpha: .4),
      1,
    );
    box(183, 122, 21, 8, const Color(0xFFE2F7FF), 2);
    box(20, 143, 192, 9, const Color(0xFF6B8AA0), 4);
    line(const Offset(74, 80), const Offset(92, 98), ice, 6);
    c.drawArc(
      const Rect.fromLTWH(65, 68, 20, 20),
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..color = ice
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );
    for (final x in [64.0, 175.0]) {
      c.save();
      c.translate(x, 149);
      c.rotate(arrive * math.pi * 5 + departure * math.pi * 4);
      c.drawCircle(Offset.zero, 21, Paint()..color = const Color(0xFF081520));
      c.drawCircle(
        Offset.zero,
        19,
        Paint()
          ..color = const Color(0xFF6A8AA0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      c.drawCircle(Offset.zero, 12, Paint()..color = const Color(0xFFADC9DC));
      line(
        const Offset(-10, 0),
        const Offset(10, 0),
        const Color(0xFF3A5264),
        3,
      );
      line(
        const Offset(0, -10),
        const Offset(0, 10),
        const Color(0xFF3A5264),
        3,
      );
      c.restore();
    }
    c.restore();
    final step = Curves.easeOutCubic.transform(
      ((arrival - .45) / .55).clamp(0.0, 1.0),
    );
    c.save();
    c.translate((1 - step) * -36, 0);
    c.saveLayer(
      const Rect.fromLTWH(220, 28, 120, 150),
      Paint()..color = Colors.white.withValues(alpha: step),
    );
    line(
      const Offset(270, 114),
      const Offset(267, 161),
      const Color(0xFF19394E),
      12,
    );
    line(
      const Offset(283, 114),
      const Offset(287, 161),
      const Color(0xFF19394E),
      12,
    );
    box(258, 160, 17, 7, const Color(0xFF081522), 2);
    box(280, 160, 16, 7, const Color(0xFF081522), 2);
    c.drawPath(
      Path()
        ..moveTo(266, 70)
        ..quadraticBezierTo(278, 65, 288, 75)
        ..lineTo(292, 116)
        ..lineTo(261, 116)
        ..close(),
      Paint()..color = blue,
    );
    line(const Offset(264, 88), const Offset(289, 88), ice, 2);
    line(
      const Offset(275, 73),
      const Offset(275, 113),
      ice.withValues(alpha: .7),
      2,
    );
    box(272, 61, 10, 13, skin, 3);
    c.drawOval(const Rect.fromLTWH(265, 38, 24, 30), Paint()..color = skin);
    c.drawPath(
      Path()
        ..moveTo(264, 51)
        ..quadraticBezierTo(262, 33, 278, 35)
        ..quadraticBezierTo(292, 35, 290, 50)
        ..lineTo(283, 43)
        ..close(),
      Paint()..color = const Color(0xFF183147),
    );
    final wave = math.sin(step * math.pi) * 7;
    line(const Offset(264, 77), const Offset(252, 99), blue, 11);
    line(const Offset(252, 99), Offset(245 - wave, 88 - wave), blue, 11);
    line(Offset(245 - wave, 88 - wave), Offset(244 - wave, 80 - wave), skin, 8);
    line(const Offset(288, 78), const Offset(300, 103), blue, 10);
    line(const Offset(300, 103), const Offset(298, 129), blue, 10);
    box(284, 131, 32, 24, const Color(0xFF54798F), 4);
    line(const Offset(293, 131), const Offset(293, 126), ice, 2);
    line(const Offset(293, 126), const Offset(305, 126), ice, 2);
    line(const Offset(305, 126), const Offset(305, 131), ice, 2);
    line(const Offset(284, 141), const Offset(316, 141), ice, 1);
    if (step > .98) {
      c.drawCircle(
        const Offset(317, 61),
        13,
        Paint()..color = const Color(0xFF175348),
      );
      line(
        const Offset(311, 61),
        const Offset(315, 65),
        const Color(0xFFB5F9DF),
        2,
      );
      line(
        const Offset(315, 65),
        const Offset(323, 56),
        const Color(0xFFB5F9DF),
        2,
      );
    }
    c.restore();
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ProviderArrivalPainter old) =>
      arrival != old.arrival ||
      departure != old.departure ||
      working != old.working ||
      progress != old.progress ||
      dark != old.dark;
}
