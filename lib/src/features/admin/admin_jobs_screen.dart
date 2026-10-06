part of '../../screens.dart';

/// Jobs workspace tab; data/actions remain in the shared admin implementation.
class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('jobs'), kind: 'jobs');
}
