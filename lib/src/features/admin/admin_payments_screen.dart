part of '../../screens.dart';

/// Payment monitoring workspace.
///
/// Completed-job payment state and payment attention filtering
/// are handled by [_AdminOperationsPanel].
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const _AdminOperationsPanel(
      key: ValueKey('payments'),
      mode: 'payments',
    );
  }
}