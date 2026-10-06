part of '../screens.dart';

class ProviderCaseDetailsScreen extends StatelessWidget {
  const ProviderCaseDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => ProviderScaffold(
    appBar: AppBar(title: const Text('Case Details')),
    body: ListView(
      padding: const EdgeInsets.all(RaSpace.xl),
      children: [
        const InfoStrip(
          icon: Icons.person_outline,
          title: 'Rajesh Kumar',
          value: '+94 77 123 4567 - Premium Member',
        ),
        const SizedBox(height: RaSpace.md),
        const InfoStrip(
          icon: Icons.directions_car_outlined,
          title: 'Toyota Innova',
          value: 'WP CAB 1234 - White',
        ),
        const SizedBox(height: RaSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RaSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                FormSectionTitle(
                  Icons.warning_amber_outlined,
                  'Incident Details',
                ),
                SizedBox(height: RaSpace.md),
                SummaryRow('Breakdown Type', 'Flat Tyre Repair'),
                SummaryRow('Location', 'Galle Road, Colombo 03'),
                SummaryRow(
                  'Customer Notes',
                  'Rear tyre is punctured. Vehicle is safely parked.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(RaRadius.md),
          child: const SizedBox(
            height: 220,
            child: MapMock(showProviders: true, showRoute: true),
          ),
        ),
        const SizedBox(height: RaSpace.md),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(RaSpace.lg),
            child: Column(
              children: [
                SummaryRow('Service Date', '25 Aug 2026 - 02:30 PM'),
                SummaryRow('Final Cost', 'Rs. 2,850', strong: true),
                SummaryRow('Status', 'Completed'),
              ],
            ),
          ),
        ),
        const SizedBox(height: RaSpace.lg),
        OutlinedButton.icon(
          onPressed: () => showCallPrompt(
            context,
            name: 'Rajesh Kumar',
            number: '+94 77 845 2210',
          ),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Contact Customer'),
        ),
      ],
    ),
  );
}
