part of '../../screens.dart';

/// Sign-in entry page. Shared authentication UI/actions are in auth_form.dart.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.isProvider});
  final bool isProvider;
  @override
  Widget build(BuildContext context) => _AuthForm(isProvider: isProvider);
}
