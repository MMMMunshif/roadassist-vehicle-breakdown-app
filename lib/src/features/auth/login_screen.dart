part of '../../screens.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.isProvider,
    this.initialRegisterMode = false,
  });
  final bool? isProvider;
  final bool initialRegisterMode;
  @override
  Widget build(BuildContext context) => _AuthForm(
    isProvider: isProvider ?? false,
    commonLogin: isProvider == null,
    initialRegisterMode: initialRegisterMode,
  );
}
