part of '../../screens.dart';

/// Complaint administration workspace.
///
/// Complaint discovery, searching and navigation to
/// [_AdminComplaintScreen] are handled by [_AdminRecords].
class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const _AdminRecords(
      key: ValueKey('complaints'),
      kind: 'complaints',
    );
  }
}