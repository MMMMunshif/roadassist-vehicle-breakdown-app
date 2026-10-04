part of '../screens.dart';

class ProviderRequestDetailsScreen extends StatelessWidget {
  const ProviderRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final latitude = (data['latitude'] as num?)?.toDouble() ?? 6.9034;
    final longitude = (data['longitude'] as num?)?.toDouble() ?? 79.8525;
    final driver = data['driverName'] as String? ?? 'Driver';
    final phone = data['driverPhone'] as String? ?? '';
    final status = (data['status'] as String? ?? 'unknown').replaceAll(
      '_',
      ' ',
    );
    final rawStatus = data['status'] as String? ?? 'unknown';
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final createdLabel = created == null
        ? 'Time unavailable'
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final registration = data['registration'] as String? ?? 'Not provided';
    final vehiclePhotos =
        (data['vehiclePhotoUrls'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Details'),
        actions: [
          if (rawStatus == 'completed')
            TextButton.icon(
              onPressed: () =>
                  push(context, InvoiceScreen(requestId: requestId)),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Invoice'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          Row(
            children: [
              StatusPill(
                label: status.toUpperCase(),
                tone: rawStatus == 'completed'
                    ? RaTone.success
                    : rawStatus == 'cancelled'
                    ? RaTone.danger
                    : RaTone.info,
              ),
              const Spacer(),
              Text('CASE $requestId', style: RaText.eyebrow),
            ],
          ),
          const SizedBox(height: RaSpace.xs),
          Text(createdLabel, style: RaText.caption),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Customer Information'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      ProfileInitials(name: driver, radius: 24),
                      const SizedBox(width: RaSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver, style: RaText.title),
                            Text(
                              phone.isEmpty ? 'Phone not provided' : phone,
                              style: RaText.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: phone.isEmpty
                            ? null
                            : () => showCallPrompt(
                                context,
                                name: driver,
                                number: phone,
                              ),
                        icon: const Icon(Icons.call_outlined),
                        tooltip: 'Call customer',
                      ),
                    ],
                  ),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => push(
                        context,
                        CustomerContactScreen(
                          requestId: requestId,
                          requestData: data,
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact Customer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Vehicle Details'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                children: [
                  SummaryRow(
                    'Type',
                    data['vehicleType'] as String? ?? 'Not provided',
                  ),
                  SummaryRow(
                    'Model',
                    data['modelYear'] as String? ?? 'Not provided',
                  ),
                  SummaryRow('Registration', registration),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Incident Details'),
          const SizedBox(height: RaSpace.sm),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(RaSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryRow(
                    'Breakdown Type',
                    data['issue'] as String? ?? 'Roadside assistance',
                  ),
                  SummaryRow(
                    'Location',
                    data['locationLabel'] as String? ?? 'Pinned location',
                  ),
                  SummaryRow(
                    'Customer Notes',
                    data['description'] as String? ?? 'No description',
                  ),
                  if ((data['notes'] as String? ?? '').trim().isNotEmpty)
                    SummaryRow('Additional Notes', data['notes'] as String),
                  const SizedBox(height: RaSpace.sm),
                  SizedBox(
                    height: 185,
                    child: MapMock(position: LatLng(latitude, longitude)),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () => openMapNavigation(
                      context,
                      latitude: latitude,
                      longitude: longitude,
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Open GPS Navigation'),
                  ),
                  if (vehiclePhotos.isNotEmpty) ...[
                    const SizedBox(height: RaSpace.md),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: vehiclePhotos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: RaSpace.sm),
                        itemBuilder: (context, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(RaRadius.sm),
                          child: Image.memory(
                            base64Decode(vehiclePhotos[index]),
                            width: 125,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: RaSpace.xxl),
                  SummaryRow(
                    'Service Charge',
                    'Rs. ${data['serviceFee'] ?? 0}',
                  ),
                  SummaryRow(
                    'Travel / Distance Charge',
                    'Rs. ${data['dispatchFee'] ?? 0}',
                  ),
                  SummaryRow('Extra Charge', 'Rs. ${data['extraFee'] ?? 0}'),
                  if ((data['providerDistanceKm'] as num?) != null)
                    SummaryRow(
                      'Provider Distance',
                      '${(data['providerDistanceKm'] as num).toStringAsFixed(1)} km',
                    ),
                  if ((data['quoteNotes'] as String? ?? '').isNotEmpty)
                    SummaryRow('Quote Notes', data['quoteNotes'] as String),
                  SummaryRow(
                    data['finalCost'] == null ? 'Quoted Total' : 'Final Total',
                    'Rs. ${data['finalCost'] ?? data['estimatedCost'] ?? 0}',
                    strong: true,
                  ),
                  if (data['driverRating'] != null)
                    SummaryRow(
                      'Driver Rating',
                      '${data['driverRating']} / 5 stars',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Assigned Provider'),
          const SizedBox(height: RaSpace.sm),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: signedIn ? AuthService().watchCurrentProfile() : null,
            builder: (context, snapshot) {
              final profile = snapshot.data?.data();
              final providerName =
                  profile?['displayName'] as String? ?? 'Service Provider';
              final services =
                  (profile?['services'] as List<dynamic>? ?? const [])
                      .whereType<String>()
                      .join(', ');
              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: ProfileInitials(name: providerName, radius: 22),
                  title: Text(providerName, style: RaText.title),
                  subtitle: Text(
                    services.isEmpty ? 'RoadAssist Provider' : services,
                    style: RaText.caption,
                    maxLines: 2,
                  ),
                  trailing: const StatusPill(
                    label: 'Assigned',
                    tone: RaTone.info,
                    dot: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: RaSpace.lg),
          const SectionTitle('Vehicle History'),
          const SizedBox(height: RaSpace.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: signedIn ? RequestService().watchProviderRequests() : null,
            builder: (context, snapshot) {
              final previous =
                  snapshot.data?.docs
                      .where((request) {
                        final requestData = request.data();
                        return request.id != requestId &&
                            registration != 'Not provided' &&
                            requestData['registration'] == registration &&
                            requestData['status'] == 'completed';
                      })
                      .take(3)
                      .toList() ??
                  const [];
              if (previous.isEmpty) {
                return const InlineMessage(
                  icon: Icons.history_outlined,
                  text:
                      'No previous completed services for this vehicle with your account.',
                );
              }
              return Card(
                color: Colors.white,
                child: Column(
                  children: previous.map((request) {
                    final history = request.data();
                    final completed = (history['completedAt'] as Timestamp?)
                        ?.toDate();
                    final date = completed == null
                        ? 'Completed service'
                        : '${completed.day.toString().padLeft(2, '0')}/${completed.month.toString().padLeft(2, '0')}/${completed.year}';
                    return ListTile(
                      leading: const IconBadge(
                        Icons.build_circle_outlined,
                        size: 36,
                      ),
                      title: Text(
                        history['issue'] as String? ?? 'Roadside assistance',
                        style: RaText.title,
                      ),
                      subtitle: Text(date, style: RaText.caption),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => push(
                        context,
                        ProviderRequestDetailsScreen(
                          requestId: request.id,
                          data: history,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
