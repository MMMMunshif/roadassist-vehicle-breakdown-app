part of '../../screens.dart';

/// Payments workspace tab; data/actions remain in the shared admin implementation.
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _AdminOperationsPanel(key: ValueKey('payments'), mode: 'payments');
}
