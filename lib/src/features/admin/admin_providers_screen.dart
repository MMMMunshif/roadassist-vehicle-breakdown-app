part of '../../screens.dart';

/// Provider administration workspace.
///
/// Provider search, pending-verification filtering and navigation
/// to the account review screen are handled by [_AdminRecords].
class AdminProvidersScreen extends StatelessWidget {
  const AdminProvidersScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const _AdminRecords(
      key: ValueKey('providers'),
      kind: 'providers',
    );
  }
}