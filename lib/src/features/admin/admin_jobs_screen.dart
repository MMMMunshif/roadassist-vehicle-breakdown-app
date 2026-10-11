part of '../../screens.dart';

/// Jobs workspace.
///
/// Job list, filtering, pagination and navigation to
/// [AdminJobMonitorScreen] are handled by [_AdminRecords].
class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminRecords(key: ValueKey('jobs'), kind: 'jobs');
  }
}
