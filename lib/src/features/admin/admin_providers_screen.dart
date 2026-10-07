part of '../../screens.dart';

/// Providers workspace tab; data/actions remain in the shared admin implementation.
class AdminProvidersScreen extends StatelessWidget {
  const AdminProvidersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminRecords(key: ValueKey('providers'), kind: 'providers');
}
