part of '../../screens.dart';

/// Audit workspace tab.
///
/// Querying, searching and record navigation are handled by
/// the shared [_AdminRecords] implementation.
class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const _AdminRecords(
      key: ValueKey(
        'audit',
      ),
      kind: 'audit',
    );
  }
}