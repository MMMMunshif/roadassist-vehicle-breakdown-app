part of '../screens.dart';

class CustomerContactScreen extends StatelessWidget {
  const CustomerContactScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  final String requestId;
  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    final driver = requestData['driverName'] as String? ?? 'Driver';
    final phone = requestData['driverPhone'] as String? ?? '';
    final status = (requestData['status'] as String? ?? 'unknown').replaceAll(
      '_',
      ' ',
    );
    final vehicle = [
      requestData['modelYear'],
      requestData['registration'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' - ');
    final issue = requestIssueLabel(requestData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Customer'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: RaSpace.md),
            child: StatusPill(label: 'Live Session', tone: RaTone.success),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Row(
                        children: [
                          ProfileInitials(name: driver, radius: 28),
                          const SizedBox(width: RaSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver, style: RaText.headline),
                                const SizedBox(height: 2),
                                Text(
                                  phone.isEmpty ? 'Phone not provided' : phone,
                                  style: RaText.bodyMuted,
                                ),
                                const SizedBox(height: RaSpace.xs),
                                const StatusPill(
                                  label: 'RoadAssist Driver',
                                  tone: RaTone.info,
                                  dot: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  const SectionTitle('Case Information'),
                  const SizedBox(height: RaSpace.sm),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      child: Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.tag_outlined,
                            label: 'Case ID',
                            value: requestId,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.sync_outlined,
                            label: 'Status',
                            value: status,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.directions_car_outlined,
                            label: 'Vehicle',
                            value: vehicle.isEmpty ? 'Not provided' : vehicle,
                          ),
                          const Divider(height: 1),
                          _ProfileInfoRow(
                            icon: Icons.warning_amber_outlined,
                            label: 'Issue Reported',
                            value: issue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  const InlineMessage(
                    icon: Icons.shield_outlined,
                    text:
                        'Customer contact details are available only for this assigned assistance request.',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(RaSpace.xl),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: raLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: phone.isEmpty
                        ? null
                        : () => showCallPrompt(
                            context,
                            name: driver,
                            number: phone,
                          ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call Customer'),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () => push(
                      context,
                      ChatScreen(
                        requestId: requestId,
                        peerName: driver,
                        peerPhone: phone,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Send Message'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: const Text('Back to Case Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
