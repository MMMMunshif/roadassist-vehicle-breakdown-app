part of '../../screens.dart';

/// Users workspace tab; data/actions remain in the shared admin implementation.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('users'), kind: 'users');
}
