part of '../../screens.dart';

class ProviderCaseDetailsScreen extends StatelessWidget {
  const ProviderCaseDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) => RaProviderScaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          BrandMark(size: 26),
          SizedBox(width: 8),
          Expanded(child: Text('Case details')),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: _WelcomeThemeToggle(),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: RaProviderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No case selected',
                    textAlign: TextAlign.center,
                    style: _providerText(
                      context,
                      size: 22,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Open a real request from Requests, Active Jobs or Job History to view customer, vehicle, location and service information.',
                    textAlign: TextAlign.center,
                    style: _providerText(context, size: 14, muted: true),
                  ),
                  const SizedBox(height: 20),
                  const InlineMessage(
                    icon: Icons.privacy_tip_outlined,
                    text:
                        'RoadAssist does not display sample customer identities or fabricated job information in production screens.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Provider Workspace'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
