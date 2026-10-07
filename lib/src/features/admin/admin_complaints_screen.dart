part of '../../screens.dart';

/// Complaints workspace tab; data/actions remain in the shared admin implementation.
class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('complaints'), kind: 'complaints');
}
