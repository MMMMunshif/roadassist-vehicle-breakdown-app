part of '../../screens.dart';

class RegistrationScreen
    extends StatelessWidget {
  const RegistrationScreen({
    super.key,
    required this.isProvider,
  });

  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    return _AuthForm(
      isProvider: isProvider,
      initialRegisterMode: true,
    );
  }
}