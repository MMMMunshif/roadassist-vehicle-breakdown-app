part of '../../screens.dart';

/// Operations workspace tab; data/actions remain in the shared admin implementation.
class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _AdminOperationsPanel(
    key: ValueKey('operations'),
    mode: 'operations',
  );
}
