part of '../../screens.dart';

class ProviderCaseDetailsScreen extends StatelessWidget {
  const ProviderCaseDetailsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Details'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(RaSpace.xl),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              padding: const EdgeInsets.all(RaSpace.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 36,
                      color: colors.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: RaSpace.xl),

                  Text(
                    'No case selected',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: RaSpace.sm),

                  Text(
                    'Open a real request from Requests, Active Jobs or Job History to view customer, vehicle, location and service information.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: RaSpace.xl),

                  const InlineMessage(
                    icon: Icons.privacy_tip_outlined,
                    text:
                        'RoadAssist does not display sample customer identities or fabricated job information in production screens.',
                  ),

                  const SizedBox(height: RaSpace.xl),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.maybePop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                      ),
                      label: const Text(
                        'Back to Provider Workspace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}