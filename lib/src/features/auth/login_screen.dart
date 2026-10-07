part of '../../screens.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.isProvider,
  });

  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    return _AuthForm(
      isProvider: isProvider,
    );
  }
}