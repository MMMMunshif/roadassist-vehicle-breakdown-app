part of '../../screens.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: dark ? const Color(0xFF041426) : const Color(0xFFF3FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => push(context, const EmergencyScreen()),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Help'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(painter: _RoleRoadPattern(dark: dark)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: ExcludeSemantics(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: dark ? .4 : .16,
                  child: Image.asset(
                    'assets/images/role_roadside_scene.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Center(child: _WelcomeBrandLogo(size: 64)),
                const SizedBox(height: 6),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Road',
                          style: TextStyle(color: colors.onSurface),
                        ),
                        const TextSpan(
                          text: 'Assist',
                          style: TextStyle(color: Color(0xFF129FEF)),
                        ),
                      ],
                    ),
                    style: roadAssistTextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Choose Account Type',
                  textAlign: TextAlign.center,
                  style: roadAssistTextStyle(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How would you like to use RoadAssist?',
                  textAlign: TextAlign.center,
                  style: roadAssistTextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 23),
                _PhotoRoleCard(
                  provider: false,
                  onTap: () =>
                      push(context, const LoginScreen(isProvider: false)),
                ),
                const SizedBox(height: 14),
                _PhotoRoleCard(
                  provider: true,
                  onTap: () =>
                      push(context, const LoginScreen(isProvider: true)),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.error.withValues(alpha: .25),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      leading: Icon(
                        Icons.emergency_outlined,
                        color: colors.error,
                      ),
                      title: Text(
                        'Need urgent help?',
                        style: roadAssistTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Emergency Guest Access'),
                      ),
                      trailing: Icon(Icons.arrow_forward, color: colors.error),
                      onTap: () => push(context, const GuestAccessScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in or create an account on the next screen.',
                  textAlign: TextAlign.center,
                  style: roadAssistTextStyle(
                    fontSize: 10,
                    height: 1.6,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoRoleCard extends StatelessWidget {
  const _PhotoRoleCard({required this.provider, required this.onTap});
  final bool provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = provider ? const Color(0xFF00C1B4) : const Color(0xFF168FFF);
    final title = provider ? 'Service Provider' : 'Driver';
    final label = provider ? 'Continue as Provider' : 'Continue as Driver';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tone.withValues(alpha: dark ? .75 : .45)),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: dark
            ? (provider ? const Color(0xFF07383F) : const Color(0xFF0A2E55))
            : (provider ? const Color(0xFFE3F7F4) : const Color(0xFFE5F2FF)),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 60,
                width: 145,
                child: ExcludeSemantics(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Colors.transparent, Colors.white],
                      stops: [0, .48],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: dark ? .85 : .8,
                      child: Image.asset(
                        'assets/images/role_roadside_scene.png',
                        fit: BoxFit.cover,
                        alignment: provider
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            provider
                                ? Icons.home_repair_service_outlined
                                : Icons.person_outline,
                            color: dark
                                ? tone
                                : (provider
                                      ? const Color(0xFF007F76)
                                      : const Color(0xFF0871C9)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider ? 'PROFESSIONAL' : 'NEED HELP?',
                                style: roadAssistTextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: dark ? tone : const Color(0xFF286386),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                style: roadAssistTextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(right: 84),
                      child: Text(
                        provider
                            ? 'Receive nearby requests and manage your service jobs.'
                            : 'Request help and track your roadside service.',
                        style: roadAssistTextStyle(fontSize: 12, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: provider
                            ? const Color(0xFF008E86)
                            : const Color(0xFF087BF5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: roadAssistTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleRoadPattern extends CustomPainter {
  const _RoleRoadPattern({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.8, -.85),
          radius: 1.15,
          colors: dark
              ? const [Color(0xFF0B354D), Color(0xFF041426)]
              : const [Color(0xFFDFF7FC), Color(0xFFF7FBFF)],
        ).createShader(rect),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? const Color(0xFF36B8E8) : const Color(0xFF69BEE9))
          .withValues(alpha: dark ? .10 : .16);
    for (var i = 0; i < 9; i++) {
      final x = size.width * (.12 + i * .15);
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(
          x + 110,
          size.height * .13,
          x - 150,
          size.height * .20,
          x - 40,
          size.height * .36,
        )
        ..cubicTo(
          x + 100,
          size.height * .52,
          x - 90,
          size.height * .75,
          x + 50,
          size.height,
        );
      canvas.drawPath(path, line);
    }
    final road = Path()
      ..moveTo(size.width * .78, 0)
      ..cubicTo(
        size.width * 1.16,
        size.height * .12,
        size.width * .48,
        size.height * .16,
        size.width * .90,
        size.height * .28,
      );
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..color = const Color(0xFF20B8ED).withValues(alpha: dark ? .06 : .08),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF20B8ED).withValues(alpha: .30);
    for (final metric in road.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 19) {
        canvas.drawPath(
          metric.extractPath(d, (d + 8).clamp(0, metric.length)),
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoleRoadPattern oldDelegate) =>
      oldDelegate.dark != dark;
}
