part of '../../screens.dart';

/// Reports workspace.
///
/// Reporting metrics, service mix and CSV export are handled by
/// [_AdminOperationsPanel].
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminOperationsPanel(
      key: ValueKey('reports'),
      mode: 'reports',
    );
  }
}
