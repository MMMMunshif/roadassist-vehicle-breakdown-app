part of '../../screens.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});
  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool checking = true, allowed = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(checkAccess());
  }

  Future<void> checkAccess() async {
    try {
      await AdminService().requireAdmin();
      if (mounted) setState(() => allowed = true);
    } catch (_) {
      if (mounted) setState(() => allowed = false);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      await AdminService().requireAdmin();
      if (mounted) setState(() => allowed = true);
      password.clear();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted)
        setState(
          () => error =
              'Sign-in failed or this account has no verified admin permission.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checking)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allowed)
      return AdminDashboardScreen(
        onSignOut: () async {
          await AuthService().signOut();
          if (mounted) setState(() => allowed = false);
        },
      );
    return Scaffold(
      appBar: AppBar(title: const Text('RoadAssist Private Admin')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Admin sign-in', style: RaText.headline),
          const Text(
            'Use an existing verified account with permission granted by the project owner.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) {
              if (!busy) login();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : login,
            child: const Text('Sign in'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
        ],
      ),
    );
  }
}
