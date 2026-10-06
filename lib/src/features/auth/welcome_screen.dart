part of '../../screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: raNavyDeep,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/welcome_assistance.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .3, .62, 1],
              colors: [
                Color(0xB3071A2C),
                Color(0x33071A2C),
                Color(0x12071A2C),
                Color(0xE6071A2C),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Help is closer than you think.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fast, trusted roadside assistance wherever your journey takes you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE5EDF5),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF075866),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => push(context, const RoleSelectionScreen()),
                    child: const Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => push(context, const RoleSelectionScreen()),
                  child: const Text(
                    'Already have an account?  Log in',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
