part of '../../screens.dart';

/// Reports workspace tab; data/actions remain in the shared admin implementation.
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminOperationsPanel(key: ValueKey('reports'), mode: 'reports');
}
