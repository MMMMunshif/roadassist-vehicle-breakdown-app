part of '../../screens.dart';

/// Registration entry page; the same validators, fields and AuthService are reused.
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key, required this.isProvider});
  final bool isProvider;
  @override
  Widget build(BuildContext context) =>
      _AuthForm(isProvider: isProvider, initialRegisterMode: true);
}
