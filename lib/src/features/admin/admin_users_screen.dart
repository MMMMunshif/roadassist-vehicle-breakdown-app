part of '../../screens.dart';

/// Users workspace tab; data/actions remain in the shared admin implementation.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('users'), kind: 'users');
}

/// Wraps on narrow screens and retains the device accessibility text scale.
class AdminUserRoleFilter extends StatelessWidget {
  const AdminUserRoleFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const {
          'all': 'All',
          'driver': 'Drivers',
          'provider': 'Providers',
        }.entries)
          ChoiceChip(
            key: ValueKey('admin-user-role-${entry.key}'),
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}
