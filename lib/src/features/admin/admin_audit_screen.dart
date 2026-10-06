part of '../../screens.dart';

/// Audit workspace tab; data/actions remain in the shared admin implementation.
class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('audit'), kind: 'audit');
}
