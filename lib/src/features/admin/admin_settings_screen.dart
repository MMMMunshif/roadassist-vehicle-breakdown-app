part of '../../screens.dart';

/// RoadAssist operational settings workspace.
///
/// Maintenance state, service availability, public notice,
/// coverage description and audited settings updates are handled
/// by [_AdminSettingsPanel].
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const _AdminSettingsPanel();
  }
}